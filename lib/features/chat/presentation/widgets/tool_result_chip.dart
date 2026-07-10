import 'package:flutter/material.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:samantha/features/chat/presentation/widgets/collapsible_block.dart';

class ToolResultChip extends StatelessWidget {
  final ToolResult result;
  const ToolResultChip({super.key, required this.result});

  IconData get _icon {
    switch (result.tool) {
      case 'read':
        return Icons.menu_book;
      case 'write':
        return Icons.edit;
      case 'edit':
        return Icons.edit_note;
      case 'bash':
        return Icons.terminal;
      case 'glob':
        return Icons.search;
      case 'grep':
        return Icons.find_in_page;
      default:
        return Icons.build;
    }
  }

  Widget _buildContent(BuildContext context) {
    final content = result.content;
    if (content == null) return const SizedBox.shrink();
    return switch (content) {
      TodoToolContent(todos: final todos) => _TodoContent(todos: todos),
      RawToolContent(content: final c) => SelectableText(
        c,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasContent = result.content != null;

    if (!hasContent) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 14, color: colorScheme.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${result.tool}: ${result.description}',
                  style: TextStyle(fontSize: 12, color: colorScheme.primary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: CollapsibleBlock(
        icon: _icon,
        label: Text(
          '${result.tool}: ${result.description}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        child: _buildContent(context),
      ),
    );
  }
}

class _TodoContent extends StatelessWidget {
  final List<TodoItem> todos;
  const _TodoContent({required this.todos});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final doneCount = todos.where((t) => t.status == 'completed').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.checklist, size: 14, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              'Todo list ($doneCount/${todos.length} done)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...todos.map(
          (todo) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: SizedBox(width: 18, height: 18, child: _TodoCheckbox(status: todo.status)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    todo.content,
                    style: TextStyle(
                      fontSize: 12,
                      color: todo.status == 'completed'
                          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.9)
                          : colorScheme.onSurface,
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

class _TodoCheckbox extends StatelessWidget {
  final String status;
  const _TodoCheckbox({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'completed':
        return Icon(Icons.check_circle, size: 18, color: colorScheme.primary);
      case 'in_progress':
        return Icon(Icons.pending, size: 18, color: colorScheme.tertiary);
      case 'cancelled':
        return Icon(Icons.cancel, size: 18, color: colorScheme.error);
      default:
        return Icon(Icons.radio_button_unchecked, size: 18, color: colorScheme.onSurfaceVariant);
    }
  }
}
