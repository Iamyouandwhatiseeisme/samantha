import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/app/theme_mode_cubit.dart';
import 'package:samantha/features/chat/data/error_message.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/chat/presentation/state/chat_state.dart';
import 'package:samantha/features/chat/presentation/widgets/collapsible_block.dart';
import 'package:samantha/features/chat/presentation/widgets/thinking_block.dart';

@RoutePage()
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  late final _revealController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  static const double _maxReveal = 48.0;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatCubit>().connect();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onRevealDragUpdate(DragUpdateDetails details) {
    _revealController.stop();
    _dragOffset += details.delta.dx;
    _dragOffset = _dragOffset.clamp(-_maxReveal, 0.0);
    _revealController.value = (-_dragOffset / _maxReveal).clamp(0.0, 1.0);
  }

  void _onRevealDragEnd(DragEndDetails details) {
    _revealController.reverse();
    _dragOffset = 0;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatCubit, ChatState>(
      listener: (context, state) {
        if (state.messages.isNotEmpty) {
          _scrollToBottom();
        }
        if (state.currentPermissionId != null) {
          _showPermissionDialog(context, state.currentPermissionTitle ?? '');
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(context),
              SizedBox(height: 16),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 4),
              BlocBuilder<ChatCubit, ChatState>(
                builder: (context, state) {
                  if (state.errorMessage == null) return const SizedBox.shrink();
                  return _ErrorBanner(message: state.errorMessage!);
                },
              ),
              Expanded(
                child: GestureDetector(
                  onHorizontalDragUpdate: _onRevealDragUpdate,
                  onHorizontalDragEnd: _onRevealDragEnd,
                  child: _MessageList(
                    scrollController: _scrollController,
                    revealController: _revealController,
                  ),
                ),
              ),
              _MessageInput(inputController: _inputController),
            ],
          ),
        ),
      ),
    );
  }

  void _showPermissionDialog(BuildContext context, String title) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(title.isNotEmpty ? title : 'Allow this action?'),
        actions: [
          TextButton(
            onPressed: () {
              ctx.read<ChatCubit>().respondToPermission(false);
              Navigator.of(ctx).pop();
            },
            child: const Text('Deny'),
          ),
          FilledButton(
            onPressed: () {
              ctx.read<ChatCubit>().respondToPermission(true);
              Navigator.of(ctx).pop();
            },
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          _iconButton(icon: Icons.arrow_back, onPressed: () => context.router.pop()),
          SizedBox(width: 8),
          const Expanded(child: _ModelTextField()),
          SizedBox(width: 8),
          const _StatusDot(),
          const SizedBox(width: 8),
          BlocBuilder<ThemeModeCubit, ThemeMode>(
            builder: (context, themeMode) {
              return _iconButton(
                icon: themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
                onPressed: () => context.read<ThemeModeCubit>().toggle(),
              );
            },
          ),
          _iconButton(icon: Icons.refresh, onPressed: () => context.read<ChatCubit>().connect()),
        ],
      ),
    );
  }

  Widget _iconButton({required IconData icon, required VoidCallback onPressed}) {
    return IconButton(
      icon: Icon(icon, size: 20),
      constraints: const BoxConstraints(minWidth: 36, maxWidth: 36, minHeight: 36, maxHeight: 36),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }
}

class _TitleState {
  final ChatConnectionStatus connectionStatus;
  final String? currentProjectPath;
  const _TitleState({required this.connectionStatus, this.currentProjectPath});
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ChatCubit, ChatState, _TitleState>(
      selector: (state) => _TitleState(
        connectionStatus: state.connectionStatus,
        currentProjectPath: state.currentProjectPath,
      ),
      builder: (context, titleState) {
        final (icon, color) = switch (titleState.connectionStatus) {
          ChatConnectionStatus.connected => (Icons.circle, Colors.green),
          ChatConnectionStatus.streaming => (Icons.circle, Colors.blue),
          ChatConnectionStatus.connecting => (Icons.sync, Colors.orange),
          ChatConnectionStatus.disconnected => (Icons.cloud_off, Colors.red),
        };

        final repoName = titleState.currentProjectPath?.split('/').last;

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 12),
              if (repoName != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    repoName,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 20, color: colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              formatErrorMessage(message),
              style: TextStyle(fontSize: 13, color: colorScheme.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: () => context.read<ChatCubit>().connect(),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onErrorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('RETRY'),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final ScrollController scrollController;
  final AnimationController revealController;

  const _MessageList({required this.scrollController, required this.revealController});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatCubit>().state;
    final messages = state.messages;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isUser = msg.role == ChatRole.user;
              final bubble = _buildBubble(context, msg, isUser);

              return AnimatedBuilder(
                animation: revealController,
                builder: (context, _) {
                  final fraction = revealController.value;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(right: fraction * 48),
                          child: bubble,
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
        ),
        if (state.currentToolName != null)
          _ToolStatusBanner(
            tool: state.currentToolName!,
            status: state.currentToolStatus ?? state.currentToolName!,
          ),
      ],
    );
  }

  Widget _buildBubble(BuildContext context, ChatMessage msg, bool isUser) {
    final footerParts = <String>[];
    if (msg.inputTokens != null || msg.outputTokens != null) {
      final total = (msg.inputTokens ?? 0) + (msg.outputTokens ?? 0);
      if (total > 0) {
        footerParts.add('${_formatTokenCount(total)} tokens');
      }
    }
    if (msg.cost != null && msg.cost! > 0) {
      footerParts.add('\$${msg.cost!.toStringAsFixed(4)}');
    }
    if (msg.duration != null && msg.duration!.inSeconds > 0) {
      footerParts.add(_formatDuration(msg.duration!));
    }

    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: isUser ? Theme.of(context).colorScheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(12.0),
          ),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          child: _ChatMessageContent(
            messageId: msg.id,
            content: msg.content,
            thinkingContent: msg.thinkingContent,
            thinkingDuration: msg.thinkingDuration,
            isStreaming: msg.isStreaming,
            toolResults: msg.toolResults,
          ),
        ),
        if (!isUser && footerParts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 2),
            child: Text(
              footerParts.join(' \u00B7 '),
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatTokenCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController inputController;

  const _MessageInput({required this.inputController});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        final isConnected = state.connectionStatus != ChatConnectionStatus.disconnected;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: inputController,
                  enabled: isConnected,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (text) => context.read<ChatCubit>().updateInput(text),
                  onSubmitted: isConnected ? (_) => _send(context) : null,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                    backgroundColor: isConnected ? Colors.blue : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isConnected ? () => _send(context) : null,
                  child: const Icon(Icons.send, size: 20),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _send(BuildContext context) {
    context.read<ChatCubit>().sendMessage();
    inputController.clear();
  }
}

class _ChatMessageContent extends StatelessWidget {
  final String messageId;
  final String content;
  final String thinkingContent;
  final Duration? thinkingDuration;
  final bool isStreaming;
  final List<ToolResult> toolResults;

  const _ChatMessageContent({
    required this.messageId,
    required this.content,
    this.thinkingContent = '',
    this.thinkingDuration,
    required this.isStreaming,
    this.toolResults = const [],
  });

  @override
  Widget build(BuildContext context) {
    final hasThinking = thinkingContent.isNotEmpty;
    // The model is still reasoning as long as the turn is live and no answer has
    // begun. Once tokens arrive, the block settles into its "Thought" label.
    final isThinking = isStreaming && content.isEmpty;

    final children = <Widget>[];

    if (hasThinking) {
      children.add(
        ThinkingBlock(
          // Pins the expand/collapse state to its message as the cubit emits a
          // fresh ChatMessage on every delta.
          key: ValueKey('thinking-$messageId'),
          text: thinkingContent,
          isThinking: isThinking,
          duration: thinkingDuration,
        ),
      );
    }

    if (isThinking) {
      if (!hasThinking) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulseDot(),
                const SizedBox(width: 8),
                const ShimmerText(
                  'Thinking…',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      }
    } else if (content.isNotEmpty) {
      final segments = _parseContent(content);

      if (segments.isEmpty) {
        children.add(
          isStreaming
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(child: Text(content)),
                    const SizedBox(width: 4),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                )
              : Text(content),
        );
      } else {
        children.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final seg in segments)
                if (seg.isCode)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: _CollapsibleCodeBlock(code: seg.text),
                  )
                else
                  Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Text(seg.text)),
              if (isStreaming)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        );
      }
    }

    for (final result in toolResults) {
      children.add(_ToolResultChip(result: result));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  List<_ContentSegment> _parseContent(String text) {
    if (!text.contains('```')) return [];

    final parts = text.split('```');
    final segments = <_ContentSegment>[];

    for (int i = 0; i < parts.length; i++) {
      if (i.isOdd) {
        final trimmed = parts[i];
        final firstLineEnd = trimmed.indexOf('\n');
        if (firstLineEnd == -1) {
          segments.add(_ContentSegment(text: '```$trimmed```', isCode: false));
          continue;
        }
        final lang = trimmed.substring(0, firstLineEnd).trim();
        if (lang == 'sh' || lang == 'bash') {
          final code = trimmed.substring(firstLineEnd + 1);
          segments.add(_ContentSegment(text: code, isCode: true));
        } else {
          segments.add(_ContentSegment(text: '```$trimmed```', isCode: false));
        }
      } else {
        if (parts[i].isNotEmpty) {
          segments.add(_ContentSegment(text: parts[i], isCode: false));
        }
      }
    }

    return segments;
  }
}

class _ContentSegment {
  final String text;
  final bool isCode;
  const _ContentSegment({required this.text, required this.isCode});
}

class _CollapsibleCodeBlock extends StatefulWidget {
  final String code;
  const _CollapsibleCodeBlock({required this.code});

  @override
  State<_CollapsibleCodeBlock> createState() => _CollapsibleCodeBlockState();
}

class _CollapsibleCodeBlockState extends State<_CollapsibleCodeBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.terminal, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Shell Command',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                widget.code,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _ModelDropdownState {
  final List<ModelProvider> availableModels;
  final String? selectedModel;
  const _ModelDropdownState({required this.availableModels, this.selectedModel});
}

class _FlatModel {
  final String qualifiedId;
  final String displayName;
  final String providerName;
  const _FlatModel(this.qualifiedId, this.displayName, this.providerName);
}

class _ModelTextField extends StatefulWidget {
  const _ModelTextField();

  @override
  State<_ModelTextField> createState() => _ModelTextFieldState();
}

class _ModelTextFieldState extends State<_ModelTextField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  String? _lastSelectedQualifier;
  bool _dismissedBySelection = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _removeOverlay();
      _restoreSelectedText();
    }
  }

  void _restoreSelectedText() {
    _dismissedBySelection = false;
  }

  void _dismiss() {
    _focusNode.unfocus();
    _removeOverlay();
    _restoreSelectedText();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  void _showOverlay(List<_FlatModel> models) {
    _removeOverlay();
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: models.length,
                itemBuilder: (ctx, index) {
                  final model = models[index];
                  return ListTile(
                    dense: true,
                    title: Text(model.displayName, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(model.providerName, style: const TextStyle(fontSize: 11)),
                    onTap: () {
                      _dismissedBySelection = true;
                      _lastSelectedQualifier = model.qualifiedId;
                      _controller.text = '${model.displayName} (${model.providerName})';
                      context.read<ChatCubit>().setModel(model.qualifiedId);
                      _focusNode.unfocus();
                      _removeOverlay();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ChatCubit, ChatState, _ModelDropdownState>(
      selector: (state) => _ModelDropdownState(
        availableModels: state.availableModels,
        selectedModel: state.selectedModel,
      ),
      builder: (context, dropdownState) {
        if (dropdownState.availableModels.isEmpty) {
          return const SizedBox(height: 36);
        }

        final allModels = <_FlatModel>[];
        for (final provider in dropdownState.availableModels) {
          for (final model in provider.models) {
            allModels.add(_FlatModel(model.qualifiedId, model.displayName, provider.name));
          }
        }

        final selected = dropdownState.selectedModel;
        if (!_dismissedBySelection && (selected != null || _lastSelectedQualifier != null)) {
          final target = selected ?? _lastSelectedQualifier;
          if (target != null && _controller.text.isEmpty) {
            final match = allModels.where((m) => m.qualifiedId == target);
            if (match.isNotEmpty) {
              final m = match.first;
              _controller.text = '${m.displayName} (${m.providerName})';
              _lastSelectedQualifier = target;
            }
          } else if (target == null) {
            _controller.clear();
          }
        }

        return CompositedTransformTarget(
          link: _layerLink,
          child: Container(
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Search models...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                contentPadding: EdgeInsets.zero,
                suffixIcon: GestureDetector(
                  onTap: () => _focusNode.requestFocus(),
                  child: const Icon(Icons.arrow_drop_down, size: 20),
                ),
              ),
              onTap: () {
                final query = _controller.text.toLowerCase();
                final filtered = query.isEmpty
                    ? allModels
                    : allModels
                          .where(
                            (m) =>
                                m.displayName.toLowerCase().contains(query) ||
                                m.providerName.toLowerCase().contains(query),
                          )
                          .toList();
                _showOverlay(filtered);
              },
              onTapOutside: (_) => _dismiss(),
              onChanged: (value) {
                _dismissedBySelection = false;
                final query = value.toLowerCase();
                final filtered = query.isEmpty
                    ? allModels
                    : allModels
                          .where(
                            (m) =>
                                m.displayName.toLowerCase().contains(query) ||
                                m.providerName.toLowerCase().contains(query),
                          )
                          .toList();
                _showOverlay(filtered);
              },
            ),
          ),
        );
      },
    );
  }
}

class _ToolResultChip extends StatelessWidget {
  final ToolResult result;
  const _ToolResultChip({required this.result});

  IconData get _icon {
    switch (result.tool) {
      case 'read':
        return Icons.menu_book;
      case 'write':
        return Icons.edit;
      case 'edit':
        return Icons.edit_note;
      case 'bash':
        return Icons.terminal;
      case 'glob':
        return Icons.search;
      case 'grep':
        return Icons.find_in_page;
      default:
        return Icons.build;
    }
  }

  Widget _buildContent(BuildContext context) {
    final content = result.content;
    if (content == null) return const SizedBox.shrink();
    return switch (content) {
      TodoToolContent(todos: final todos) => _TodoContent(todos: todos),
      RawToolContent(content: final c) => SelectableText(
        c,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasContent = result.content != null;

    if (!hasContent) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 14, color: colorScheme.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${result.tool}: ${result.description}',
                  style: TextStyle(fontSize: 12, color: colorScheme.primary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: CollapsibleBlock(
        icon: _icon,
        label: Text(
          '${result.tool}: ${result.description}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        child: _buildContent(context),
      ),
    );
  }
}

class _TodoContent extends StatelessWidget {
  final List<TodoItem> todos;
  const _TodoContent({required this.todos});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final doneCount = todos.where((t) => t.status == 'completed').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.checklist, size: 14, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              'Todo list ($doneCount/${todos.length} done)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...todos.map(
          (todo) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: SizedBox(width: 18, height: 18, child: _TodoCheckbox(status: todo.status)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    todo.content,
                    style: TextStyle(
                      fontSize: 12,
                      color: todo.status == 'completed'
                          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.9)
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TodoCheckbox extends StatelessWidget {
  final String status;
  const _TodoCheckbox({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'completed':
        return Icon(Icons.check_circle, size: 18, color: colorScheme.primary);
      case 'in_progress':
        return Icon(Icons.pending, size: 18, color: colorScheme.tertiary);
      case 'cancelled':
        return Icon(Icons.cancel, size: 18, color: colorScheme.error);
      default:
        return Icon(Icons.radio_button_unchecked, size: 18, color: colorScheme.onSurfaceVariant);
    }
  }
}

class _ToolStatusBanner extends StatelessWidget {
  final String tool;
  final String status;
  const _ToolStatusBanner({required this.tool, required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Icon(Icons.build, size: 14, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              status,
              style: TextStyle(fontSize: 12, color: colorScheme.onSecondaryContainer),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
