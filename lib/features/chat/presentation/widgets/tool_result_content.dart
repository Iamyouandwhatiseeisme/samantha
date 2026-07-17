import 'package:flutter/material.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:samantha/features/chat/presentation/widgets/todo_content.dart';

class ToolResultContent extends StatelessWidget {
  final ToolContent content;
  const ToolResultContent({required this.content});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return switch (content) {
      TodoToolContent(todos: final todos) => TodoContent(todos: todos),
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
