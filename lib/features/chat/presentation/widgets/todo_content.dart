import 'package:flutter/material.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/common/extensions/context_x.dart';
import 'package:samantha/features/chat/domain/entities.dart';

class TodoContent extends StatelessWidget {
  final List<TodoItem> todos;
  const TodoContent({required this.todos});

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
              context.l10n.todosDone(doneCount, todos.length),
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
                  child: SizedBox(width: 16, height: 16, child: TodoCheckbox(status: todo.status)),
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

class TodoCheckbox extends StatelessWidget {
  final String status;
  const TodoCheckbox({required this.status});

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
