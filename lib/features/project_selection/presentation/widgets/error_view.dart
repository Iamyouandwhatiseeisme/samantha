import 'package:flutter/material.dart';
import 'package:samantha/features/chat/data/error_message.dart';

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBackToSettings;

  const ErrorView({
    required this.message,
    required this.onRetry,
    required this.onBackToSettings,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('Failed to load data', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              formatErrorMessage(message),
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onBackToSettings,
              child: const Text('Back to Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
