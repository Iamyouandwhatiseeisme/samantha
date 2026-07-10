import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/features/chat/data/error_message.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';

class ErrorBanner extends StatelessWidget {
  final String message;
  const ErrorBanner({super.key, required this.message});

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
