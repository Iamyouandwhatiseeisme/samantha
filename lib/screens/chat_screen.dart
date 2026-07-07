import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/cubit/chat_cubit.dart';
import 'package:samantha/models/settings.dart';
import 'package:samantha/screens/settings_screen.dart';

class ChatScreen extends StatelessWidget {
  final ConnectionSettings settings;

  const ChatScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Samantha — ${settings.host}:${settings.port}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.of(context).push<ConnectionSettings>(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
              if (result != null && context.mounted) {
                final cubit = context.read<ChatCubit>();
                await cubit.connect(result);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _ConnectionStatusBanner(),
          Expanded(child: _MessageList()),
          _MessageInput(),
        ],
      ),
    );
  }
}

class _ConnectionStatusBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final status = context.watch<ChatCubit>().state.connectionStatus;
    final error = context.watch<ChatCubit>().state.errorMessage;

    if (status == ConnectionStatus.connected) {
      return const SizedBox.shrink();
    }

    return MaterialBanner(
      content: Text(status == ConnectionStatus.connecting
          ? 'Connecting...'
          : error ?? 'Disconnected'),
      backgroundColor: status == ConnectionStatus.connecting
          ? Colors.orange.shade100
          : Colors.red.shade100,
      actions: status == ConnectionStatus.disconnected
          ? <Widget>[
              TextButton(
                onPressed: () {
                  // reconnect handled in main.dart flow
                },
                child: const Text('RECONNECT'),
              ),
            ]
          : <Widget>[],
    );
  }
}

class _MessageList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final messages = context.watch<ChatCubit>().state.messages;

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final msg = messages[index];
          return Align(
            alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: msg.isUser
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12.0),
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Text(msg.content),
            ),
          );
        },
      ),
    );
  }
}

class _MessageInput extends StatefulWidget {
  @override
  State<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<_MessageInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = context.watch<ChatCubit>().state.connectionStatus ==
        ConnectionStatus.connected;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: isConnected,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(),
              ),
              onChanged: (text) => context.read<ChatCubit>().updateInput(text),
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
  }

  void _send(BuildContext context) {
    context.read<ChatCubit>().sendMessage();
    _controller.clear();
  }
}
