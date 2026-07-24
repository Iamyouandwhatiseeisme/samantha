import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:samantha/common/extensions/date_time_x.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/chat/presentation/state/chat_state.dart';
import 'package:samantha/features/chat/presentation/widgets/message_bubble.dart';
import 'package:samantha/features/chat/presentation/widgets/scroll_to_bottom_fab.dart';
import 'package:samantha/features/chat/presentation/widgets/tool_status_banner.dart';

class MessageList extends StatefulWidget {
  final ScrollController scrollController;
  final AnimationController revealController;
  final double maxReveal;

  const MessageList({
    super.key,
    required this.scrollController,
    required this.revealController,
    required this.maxReveal,
  });

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> with SingleTickerProviderStateMixin {
  // Presentation flag — mirrors whether the "scroll to bottom" chevron shows.
  // Reflects the observed fact that content is taller than the viewport AND the
  // viewport is not currently near the bottom.
  late final ValueNotifier<bool> _showScrollToBottom;

  // Intent flag — the single source of truth every auto-scroll path checks.
  // When true the view wants the newest content pinned to the bottom as it
  // grows. Deliberately separate from the presentation flag above.
  bool _followsStream = true;

  // Scroll-geometry bookkeeping for the follow/unfollow decision.
  double _lastOffsetY = 0;
  double _lastContentHeight = -1;
  double _lastViewport = -1;
  // Re-entrancy guard: programmatic jumps fire scroll notifications, which we
  // must ignore to avoid feedback loops and stale-size misreads.
  bool _isPinning = false;

  // Discrete-event bookkeeping (analog of TranscriptTailKey + isStreaming).
  int _prevCount = 0;
  String? _prevLastId;
  ChatRole? _prevLastRole;
  bool _prevWasStreaming = false;

  final List<Timer> _settleTimers = [];

  // Thresholds (see ChatView.scroll_position_control.md).
  static const double _nearBottomSlack = 60; // px from bottom = "near"
  static const double _scrollUpDeadband = 8; // px; smaller upward moves ignored
  static const double _scrollableOverflow = 8; // px; content taller than this is scrollable

  // Search state
  bool _searchVisible = false;
  double _overscrollAccumulator = 0;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late AnimationController _searchAnimationController;
  late Animation<double> _searchAnimation;
  String _searchQuery = '';

  static const _pullThreshold = 40.0;

  @override
  void initState() {
    super.initState();
    _showScrollToBottom = ValueNotifier(false);
    widget.scrollController.addListener(_onScroll);
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeOut,
    );
    // First appearance: settle at the tail (newest message), like onAppear.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _settleAtTail();
    });
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    for (final t in _settleTimers) {
      t.cancel();
    }
    _settleTimers.clear();
    _showScrollToBottom.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }

  /// Geometry-change handler (analog of onScrollGeometryChange). Fires on any
  /// scroll or extent change and:
  ///  1. updates the follow intent from user motion,
  ///  2. recomputes the chevron flag,
  ///  3. re-pins the tail while following — but only on a content/viewport size
  ///     change, so a pure user offset change never fights the user.
  void _onScroll() {
    if (_isPinning) return; // ignore notifications we just caused
    final controller = widget.scrollController;
    if (!controller.hasClients) return;

    final maxScroll = controller.position.maxScrollExtent;
    final current = controller.position.pixels;
    final viewport = controller.position.viewportDimension;
    final contentHeight = maxScroll + viewport;

    final nearBottom = (maxScroll - current) <= _nearBottomSlack;
    final sizeChanged =
        contentHeight != _lastContentHeight || viewport != _lastViewport;

    // 1. Update follow intent from user motion.
    // Reaching the bottom re-arms following (by any means, including dragging
    // back down). Only an upward move past the deadband disengages it; the
    // asymmetry means tiny layout nudges never drop following spuriously.
    if (nearBottom) {
      _followsStream = true;
    } else if (current < _lastOffsetY - _scrollUpDeadband) {
      _followsStream = false;
    }

    // 2/3. Keep the tail pinned while following on a size change, and compute
    // the chevron flag against the post-pin position so it never flashes during
    // growth-before-repin.
    if (_followsStream && sizeChanged && maxScroll > 0) {
      _pinToTailImmediate();
      final pinned = controller.position.pixels;
      final pinnedNearBottom =
          (controller.position.maxScrollExtent - pinned) <= _nearBottomSlack;
      final scrollable =
          controller.position.maxScrollExtent > _scrollableOverflow;
      final scrolledUp = scrollable && !pinnedNearBottom;
      if (_showScrollToBottom.value != scrolledUp) {
        _showScrollToBottom.value = scrolledUp;
      }
    } else {
      final scrollable = maxScroll > _scrollableOverflow;
      final scrolledUp = scrollable && !nearBottom;
      if (_showScrollToBottom.value != scrolledUp) {
        _showScrollToBottom.value = scrolledUp;
      }
    }

    _lastOffsetY = controller.position.pixels;
    _lastContentHeight = contentHeight;
    _lastViewport = viewport;
  }

  /// Instant single re-pin to the tail (the geometry-path re-pin). Uses jumpTo
  /// so it clamps to the live maxScrollExtent — it can neither overshoot nor
  /// land short, which is what prevents the overscroll/halfway symptoms.
  void _pinToTailImmediate() {
    final controller = widget.scrollController;
    if (!controller.hasClients) return;
    final target = controller.position.maxScrollExtent;
    if ((target - controller.position.pixels).abs() < 2) return;
    _isPinning = true;
    controller.jumpTo(target);
    _isPinning = false;
  }

  /// Settle at the tail: jump once, then re-jump at 80ms and 350ms to absorb
  /// asynchronous layout (markdown rendering, row expansion) that finishes
  /// after the first jump. Each delayed pass re-checks the follow intent, so
  /// scrolling up during the window aborts the remaining passes.
  void _settleAtTail() {
    if (!_followsStream) return;
    _pinToTailImmediate();
    for (final delay in const [80, 350]) {
      _settleTimers.add(
        Timer(Duration(milliseconds: delay), () {
          if (!mounted || !_followsStream) return;
          _pinToTailImmediate();
        }),
      );
    }
    _settleTimers.removeWhere((t) => !t.isActive);
  }

  /// Scroll-to-bottom button: re-arm following and animate to the tail. There
  /// is no competing per-token auto-scroll anymore (the geometry path uses
  /// instant jumps), so a single animateTo cannot be fought into an overshoot.
  /// If content grows/shrinks mid-animation, the size-change re-pin clamps to
  /// the live bottom; a final settle catches any residual layout.
  void _onButtonPressed() {
    _followsStream = true;
    final controller = widget.scrollController;
    if (!controller.hasClients) return;
    final target = controller.position.maxScrollExtent;
    if ((target - controller.position.pixels).abs() < 2) {
      _settleAtTail();
      return;
    }
    controller
        .animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        )
        .then((_) {
      if (!mounted) return;
      _settleAtTail();
    });
  }

  void _showSearch() {
    setState(() {
      _searchVisible = true;
      _overscrollAccumulator = 0;
    });
    _searchAnimationController.forward();
    _searchFocus.requestFocus();
  }

  void _hideSearch() {
    _searchAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _searchVisible = false;
          _searchQuery = '';
        });
        _searchController.clear();
      }
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_searchVisible) return false;

    if (notification is ScrollUpdateNotification && notification.metrics.pixels <= 0) {
      if (notification.dragDetails != null && notification.dragDetails!.delta.dy > 0) {
        _overscrollAccumulator += notification.dragDetails!.delta.dy;
        if (_overscrollAccumulator > _pullThreshold) {
          _showSearch();
          return true;
        }
      }
    }

    if (notification is ScrollEndNotification) {
      _overscrollAccumulator = 0;
    }

    return false;
  }

  List<ChatMessage> _filterMessages(List<ChatMessage> messages) {
    if (_searchQuery.isEmpty) return messages;
    final query = _searchQuery.toLowerCase();
    return messages.where((m) {
      if (m.content.toLowerCase().contains(query)) return true;
      if (m.thinkingContent.toLowerCase().contains(query)) return true;
      for (final result in m.toolResults) {
        if (result.tool.toLowerCase().contains(query)) return true;
        if (result.description.toLowerCase().contains(query)) return true;
      }
      return false;
    }).toList();
  }

  /// Discrete-event handler (analog of the onChange observers). Respects
  /// followsStream everywhere except when the user sends a message, which
  /// always yanks to the bottom.
  void _onStateChanged(ChatState state) {
    if (state.messages.isEmpty) {
      _prevCount = 0;
      _prevLastId = null;
      _prevLastRole = null;
      _prevWasStreaming =
          state.connectionStatus == ChatConnectionStatus.streaming;
      return;
    }

    final count = state.messages.length;
    final last = state.messages.last;
    final isStreaming = state.connectionStatus == ChatConnectionStatus.streaming;

    final countGrew = count > _prevCount;
    final tailChanged = last.id != _prevLastId || last.role != _prevLastRole;
    final streamEnded = _prevWasStreaming && !isStreaming;
    // A user turn was appended — either the user just sent, or session history
    // loaded. Both should land at the bottom regardless of current position.
    final appendedUser = countGrew &&
        state.messages.sublist(max(0, _prevCount)).any((m) => m.role == ChatRole.user);

    if (appendedUser) {
      _followsStream = true;
      _settleAtTail();
    } else if (tailChanged && _followsStream) {
      _settleAtTail();
    } else if (streamEnded && _followsStream) {
      _settleAtTail();
    }

    _prevCount = count;
    _prevLastId = last.id;
    _prevLastRole = last.role;
    _prevWasStreaming = isStreaming;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatCubit>().state;
    final messages = _filterMessages(state.messages);

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: BlocListener<ChatCubit, ChatState>(
        listenWhen: (prev, next) {
          if (prev.messages.isEmpty != next.messages.isEmpty) return true;
          if (next.messages.isEmpty) return false;
          final p = prev.messages.last;
          final n = next.messages.last;
          return prev.messages.length != next.messages.length ||
              p.id != n.id ||
              p.role != n.role ||
              prev.connectionStatus != next.connectionStatus;
        },
        listener: (context, state) => _onStateChanged(state),
        child: Column(
          children: [
            if (_searchVisible)
              SizeTransition(
                sizeFactor: _searchAnimation,
                child: _SearchBar(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: _onSearchChanged,
                  onClear: _hideSearch,
                ),
              ),
            if (!_searchVisible) const _PullCue(),
            Expanded(
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: widget.revealController,
                    builder: (context, _) {
                      final shift = -widget.revealController.value * widget.maxReveal;
                      return ClipRect(
                        clipper: _VerticalClipper(horizontalSlack: widget.maxReveal),
                        child: Transform.translate(
                          offset: Offset(shift, 0),
                          child: ListView.builder(
                            controller: widget.scrollController,
                            clipBehavior: Clip.none,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              final isUser = msg.role == ChatRole.user;
                              return AnimatedBuilder(
                                animation: widget.revealController,
                                builder: (context, _) {
                                  final fraction = widget.revealController.value;
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Align(
                                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                        child: MessageBubble(
                                          msg: msg,
                                          isUser: isUser,
                                          searchQuery: _searchQuery,
                                        ),
                                      ),
                                      Positioned(
                                        right: -fraction * widget.maxReveal,
                                        bottom: 4,
                                        child: Opacity(
                                          opacity: fraction,
                                          child: Text(
                                            msg.timestamp.toTimeString(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: ScrollToBottomFab(
                      showScrollToBottom: _showScrollToBottom,
                      onPressed: _onButtonPressed,
                    ),
                  ),
                ],
              ),
            ),
            if (state.currentToolName != null)
              ToolStatusBanner(
                tool: state.currentToolName!,
                status: state.currentToolStatus ?? state.currentToolName!,
              ),
          ],
        ),
      ),
    );
  }
}

class _VerticalClipper extends CustomClipper<Rect> {
  final double horizontalSlack;

  const _VerticalClipper({required this.horizontalSlack});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(-horizontalSlack, 0, size.width + horizontalSlack, size.height);
  }

  @override
  bool shouldReclip(_VerticalClipper oldClipper) =>
      horizontalSlack != oldClipper.horizontalSlack;
}

class _PullCue extends StatelessWidget {
  const _PullCue();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Text(
            'Pull down to search',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surface,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          hintText: 'Search messages...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onClear,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.colorScheme.primary),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          isDense: true,
        ),
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
      ),
    );
  }
}
