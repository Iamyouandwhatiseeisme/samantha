import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
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

  const MessageList({super.key, required this.scrollController, required this.revealController});

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
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

  @override
  void initState() {
    super.initState();
    _showScrollToBottom = ValueNotifier(false);
    widget.scrollController.addListener(_onScroll);
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
    final messages = state.messages;

    return BlocListener<ChatCubit, ChatState>(
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
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: widget.scrollController,
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
                              child: Padding(
                                padding: EdgeInsets.only(right: fraction * 48),
                                child: MessageBubble(msg: msg, isUser: isUser),
                              ),
                            ),
                            Positioned(
                              right: (fraction - 1) * 48,
                              bottom: 4,
                              child: Opacity(
                                opacity: fraction,
                                child: Text(
                                  _formatTime(msg.timestamp),
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
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
