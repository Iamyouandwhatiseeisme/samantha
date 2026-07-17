import 'package:flutter/material.dart';
import 'package:samantha/app/theme.dart';

class HighlightedDiffLine extends StatelessWidget {
  final String line;
  final AppColors colors;

  const HighlightedDiffLine({required this.line, required this.colors, super.key});

  @override
  Widget build(BuildContext context) {
    final isAdd = line.startsWith('+');
    final isRemove = line.startsWith('-');
    final isHunk = line.startsWith('@@');

    Color? bg;
    Color? fg;
    if (isAdd) {
      bg = colors.diffAddBg;
      fg = colors.diffAdd;
    } else if (isRemove) {
      bg = colors.diffRemoveBg;
      fg = colors.diffRemove;
    } else if (isHunk) {
      fg = Theme.of(context).colorScheme.tertiary;
    }

    return DecoratedBox(
      decoration: BoxDecoration(color: bg),
      child: Padding(
        padding: EdgeInsets.only(
          left: isAdd || isRemove ? 0 : 4,
          right: 8,
        ),
        child: Text(
          line,
          style: TextStyle(
            fontFamily: colors.mono,
            fontSize: 13,
            height: 1.5,
            color: fg ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
