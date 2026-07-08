import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/app/router.dart';
import 'package:samantha/app/theme_mode_cubit.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/chat/presentation/state/chat_state.dart';

@RoutePage()
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();

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
          child: Column(
            children: [
              _buildTopBar(context),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 4),
              BlocBuilder<ChatCubit, ChatState>(
                builder: (context, state) {
                  if (state.errorMessage == null) return const SizedBox.shrink();
                  return _ErrorBanner(message: state.errorMessage!);
                },
              ),
              Expanded(child: _MessageList(scrollController: _scrollController)),
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
          _iconButton(
            icon: Icons.settings,
            onPressed: () => context.router.replace(
              const ConnectionSettingsRoute(),
            ),
          ),
          Expanded(child: _buildTitle()),
          BlocBuilder<ThemeModeCubit, ThemeMode>(
            builder: (context, themeMode) {
              return _iconButton(
                icon: themeMode == ThemeMode.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
                onPressed: () => context.read<ThemeModeCubit>().toggle(),
              );
            },
          ),
          _iconButton(
            icon: Icons.refresh,
            onPressed: () => context.read<ChatCubit>().connect(),
          ),
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20),
      constraints: const BoxConstraints(minWidth: 36, maxWidth: 36, minHeight: 36, maxHeight: 36),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }

  Widget _buildTitle() {
    return BlocSelector<ChatCubit, ChatState, _TitleState>(
      selector: (state) => _TitleState(
        connectionStatus: state.connectionStatus,
        currentProjectPath: state.currentProjectPath,
      ),
      builder: (context, titleState) {
        final (icon, label) = switch (titleState.connectionStatus) {
          ChatConnectionStatus.connected => (Icons.circle, 'Connected'),
          ChatConnectionStatus.streaming => (Icons.circle, 'Streaming'),
          ChatConnectionStatus.connecting => (Icons.sync, 'Connecting...'),
          ChatConnectionStatus.disconnected => (Icons.cloud_off, 'Disconnected'),
        };

        Color color = switch (titleState.connectionStatus) {
          ChatConnectionStatus.connected => Colors.green,
          ChatConnectionStatus.streaming => Colors.blue,
          ChatConnectionStatus.connecting => Colors.orange,
          ChatConnectionStatus.disconnected => Colors.red,
        };

        final repoName = titleState.currentProjectPath
            ?.split('/')
            .last;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 12),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (repoName != null)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  repoName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 8),
            const _ModelDropdown(),
          ],
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
    return MaterialBanner(
      backgroundColor: Colors.red.shade100,
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => context.read<ChatCubit>().connect(),
          child: const Text('RETRY'),
        ),
      ],
    );
  }
}

class _MessageList extends StatelessWidget {
  final ScrollController scrollController;

  const _MessageList({required this.scrollController});

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

              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
            child: _ChatMessageContent(
              content: msg.content,
              thinkingContent: msg.thinkingContent,
              isStreaming: msg.isStreaming,
              toolResults: msg.toolResults,
            ),
                ),
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
}

class _MessageInput extends StatelessWidget {
  final TextEditingController inputController;

  const _MessageInput({required this.inputController});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        final isConnected = state.connectionStatus !=
            ChatConnectionStatus.disconnected;

        return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: inputController,
                  enabled: isConnected,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (text) =>
                      context.read<ChatCubit>().updateInput(text),
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
  final String content;
  final String thinkingContent;
  final bool isStreaming;
  final List<ToolResult> toolResults;

  const _ChatMessageContent({
    required this.content,
    this.thinkingContent = '',
    required this.isStreaming,
    this.toolResults = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasThinking = thinkingContent.isNotEmpty;
    final isEmptyContent = isStreaming && content.isEmpty;

    final children = <Widget>[];

    if (hasThinking) {
      children.add(
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.psychology,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Thinking',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                thinkingContent,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isEmptyContent) {
      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Thinking...'),
            const SizedBox(width: 4),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      );
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(seg.text),
                  ),
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
          segments.add(
            _ContentSegment(text: '```$trimmed```', isCode: false),
          );
          continue;
        }
        final lang = trimmed.substring(0, firstLineEnd).trim();
        if (lang == 'sh' || lang == 'bash') {
          final code = trimmed.substring(firstLineEnd + 1);
          segments.add(_ContentSegment(text: code, isCode: true));
        } else {
          segments.add(
            _ContentSegment(text: '```$trimmed```', isCode: false),
          );
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
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _TitleState {
  final ChatConnectionStatus connectionStatus;
  final String? currentProjectPath;
  const _TitleState({required this.connectionStatus, this.currentProjectPath});
}

class _ModelDropdownState {
  final List<ModelProvider> availableModels;
  final String? selectedModel;
  const _ModelDropdownState({required this.availableModels, this.selectedModel});
}

class _ModelDropdown extends StatelessWidget {
  const _ModelDropdown();

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

        final items = <DropdownMenuItem<String>>[];
        for (final provider in dropdownState.availableModels) {
          for (final model in provider.models) {
            items.add(DropdownMenuItem(
              value: model.qualifiedId,
              child: Text(
                '${model.displayName} (${provider.name})',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ));
          }
        }

        final selected = dropdownState.selectedModel;
        final hasValidSelection =
            selected != null && items.any((i) => i.value == selected);

        final hintText = items.isNotEmpty
            ? (items.first.child as Text).data ?? 'Select model'
            : 'Select model';

        return Container(
          height: 36,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: hasValidSelection ? selected : null,
              hint: Text(hintText, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
              isDense: true,
              isExpanded: true,
              items: items,
              onChanged: (model) {
                if (model != null) {
                  context.read<ChatCubit>().setModel(model);
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class _ToolResultChip extends StatefulWidget {
  final ToolResult result;
  const _ToolResultChip({required this.result});

  @override
  State<_ToolResultChip> createState() => _ToolResultChipState();
}

class _ToolResultChipState extends State<_ToolResultChip> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasContent = widget.result.content != null && widget.result.content!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: hasContent ? () => setState(() => _expanded = !_expanded) : null,
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
                      '${widget.result.tool}: ${widget.result.description}',
                      style: TextStyle(fontSize: 12, color: colorScheme.primary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasContent) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_expanded && hasContent)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        widget.result.tool,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    widget.result.content!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Icon(Icons.build, size: 14, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSecondaryContainer,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
