import 'package:flutter/material.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/common/extensions/string_x.dart';

class ToolStatusBanner extends StatelessWidget {
  final String tool;
  final String status;
  const ToolStatusBanner({super.key, required this.tool, required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Icon(tool.toToolIcon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                fontFamily: colors.mono,
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
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
