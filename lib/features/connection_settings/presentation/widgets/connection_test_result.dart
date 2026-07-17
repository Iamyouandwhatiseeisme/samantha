import 'package:flutter/material.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/features/chat/data/error_message.dart';
import 'package:samantha/features/connection_settings/presentation/state/connection_settings_state.dart';

class ConnectionTestResult extends StatelessWidget {
  final ConnectionSettingsState state;

  const ConnectionTestResult({required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    return switch (state) {
      ConnectionSettingsTestSuccess() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.success.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 16, color: colors.success),
              const SizedBox(width: 8),
              Text(
                'Connection successful',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ConnectionSettingsTestFailure(:final message) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.error.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 16, color: colors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formatErrorMessage(message),
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
