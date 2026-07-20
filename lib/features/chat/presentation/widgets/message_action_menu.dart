import 'package:flutter/material.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/common/extensions/context_x.dart';
import 'package:samantha/features/chat/domain/entities.dart';

enum MessageAction {
  retry,
  edit,
  copyCode,
  branch,
}

class MessageActionMenu extends StatelessWidget {
  final ChatMessage message;
  final bool isUser;
  final VoidCallback onRetry;
  final VoidCallback onEdit;
  final VoidCallback onCopyCode;
  final VoidCallback onBranch;

  const MessageActionMenu({
    required this.message,
    required this.isUser,
    required this.onRetry,
    required this.onEdit,
    required this.onCopyCode,
    required this.onBranch,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    final actions = <({MessageAction action, IconData icon, String label, VoidCallback onTap})>[
      if (!isUser && !message.isStreaming)
        (
          action: MessageAction.retry,
          icon: Icons.refresh,
          label: context.l10n.messageActionsRetry,
          onTap: onRetry,
        ),
      if (isUser)
        (
          action: MessageAction.edit,
          icon: Icons.edit,
          label: context.l10n.messageActionsEdit,
          onTap: onEdit,
        ),
      (
        action: MessageAction.copyCode,
        icon: Icons.code,
        label: context.l10n.messageActionsCopyCode,
        onTap: onCopyCode,
      ),
      (
        action: MessageAction.branch,
        icon: Icons.call_split,
        label: context.l10n.messageActionsBranch,
        onTap: onBranch,
      ),
    ];

    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: actions
            .map(
              (a) => InkWell(
                onTap: a.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(a.icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Text(
                        a.label,
                        style: TextStyle(
                          fontFamily: colors.mono,
                          fontSize: 12,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
