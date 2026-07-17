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

class _TodoContent extends StatelessWidget {
  final List<TodoItem> todos;
  const _TodoContent({required this.todos});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    final doneCount = todos.where((t) => t.status == 'completed').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.checklist, size: 13, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              '$doneCount/${todos.length} done',
              style: TextStyle(
                fontFamily: colors.mono,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...todos.map(
          (todo) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: SizedBox(width: 16, height: 16, child: _TodoCheckbox(status: todo.status)),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    todo.content,
                    style: TextStyle(
                      fontFamily: colors.mono,
                      fontSize: 11,
                      height: 1.4,
                      color: todo.status == 'completed'
                          ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolResultContent extends StatelessWidget {
  final ToolContent content;
  const _ToolResultContent({required this.content});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return switch (content) {
      TodoToolContent(todos: final todos) => _TodoContent(todos: todos),
      RawToolContent(content: final c) => SelectableText(
          c,
          style: TextStyle(
            fontFamily: colors.mono,
            fontSize: 12,
            height: 1.4,
            color: theme.colorScheme.onSurface,
          ),
        ),
    };
  }
}

class _TodoCheckbox extends StatelessWidget {
  final String status;
  const _TodoCheckbox({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    switch (status) {
      case 'completed':
        return Icon(Icons.check_circle, size: 15, color: colors.success);
      case 'in_progress':
        return Icon(Icons.pending, size: 15, color: Theme.of(context).colorScheme.tertiary);
      case 'cancelled':
        return Icon(Icons.cancel, size: 15, color: colors.error);
      default:
        return Icon(Icons.radio_button_unchecked, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant);
    }
  }
}
