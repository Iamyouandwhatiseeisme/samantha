import 'package:flutter/material.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/common/extensions/string_x.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:samantha/features/chat/presentation/widgets/collapsible_block.dart';
import 'package:samantha/features/chat/presentation/widgets/tool_result_content.dart';

class ToolResultChip extends StatelessWidget {
  final ToolResult result;
  const ToolResultChip({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final hasContent = result.content != null;

    if (!hasContent) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: colors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: colors.success.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 12, color: colors.success),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${result.tool}: ${result.description}',
                  style: TextStyle(
                    fontFamily: colors.mono,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: CollapsibleBlock(
        icon: result.tool.toToolIcon,
        label: Text('${result.tool}: ${result.description}'),
        child: ToolResultContent(content: result.content!),
      ),
    );
  }
}

