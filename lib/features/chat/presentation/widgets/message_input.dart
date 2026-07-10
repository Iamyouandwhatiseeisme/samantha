import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/chat/presentation/state/chat_state.dart';

class MessageInput extends StatelessWidget {
  final TextEditingController inputController;

  const MessageInput({super.key, required this.inputController});

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
