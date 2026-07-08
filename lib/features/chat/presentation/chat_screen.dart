import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/app/router.dart';
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
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F0F0),
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

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.router.replace(
              const ConnectionSettingsRoute(),
            ),
          ),
          Expanded(child: _buildTitle()),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ChatCubit>().connect(),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        final (icon, label) = switch (state.connectionStatus) {
          ChatConnectionStatus.connected => (Icons.circle, 'Connected'),
          ChatConnectionStatus.streaming => (Icons.circle, 'Streaming'),
          ChatConnectionStatus.connecting => (Icons.sync, 'Connecting...'),
          ChatConnectionStatus.disconnected => (Icons.cloud_off, 'Disconnected'),
        };

        Color color = switch (state.connectionStatus) {
          ChatConnectionStatus.connected => Colors.green,
          ChatConnectionStatus.streaming => Colors.blue,
          ChatConnectionStatus.connecting => Colors.orange,
          ChatConnectionStatus.disconnected => Colors.red,
        };

        final repoName = state.currentProjectPath
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
            _ModelDropdown(),
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
    final messages = context.watch<ChatCubit>().state.messages;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
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
            child: msg.isStreaming
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          msg.content.isEmpty ? 'Thinking...' : msg.content,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  )
                : Text(msg.content),
          ),
        );
      },
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
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: inputController,
                  enabled: isConnected,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (text) =>
                      context.read<ChatCubit>().updateInput(text),
                  onSubmitted: (_) => _send(context),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: isConnected ? () => _send(context) : null,
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

class _ModelDropdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        if (state.availableModels.isEmpty) {
          return const SizedBox.shrink();
        }

        final items = <DropdownMenuItem<String>>[];
        for (final provider in state.availableModels) {
          for (final model in provider.models) {
            items.add(DropdownMenuItem(
              value: model.qualifiedId,
              child: Text(
                '${model.displayName} (${provider.name})',
                style: const TextStyle(fontSize: 13),
              ),
            ));
          }
        }

        final selected = state.selectedModel;
        final hasValidSelection =
            selected != null && items.any((i) => i.value == selected);

        return SizedBox(
          height: 36,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: hasValidSelection ? selected : null,
              hint: const Text('Model', style: TextStyle(fontSize: 13)),
              isDense: true,
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
