import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:samantha/app/theme.dart';

class ScrollToBottomButton extends StatelessWidget {
  const ScrollToBottomButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final bgColor = theme.colorScheme.surfaceContainerHigh;
    final fgColor = theme.colorScheme.onSurface;

    return Center(
      child: GestureDetector(
        onTap: onPressed,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.only(top: 8, bottom: 8, left: 14, right: 16),
              decoration: BoxDecoration(
                color: bgColor.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.all(Radius.circular(100)),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_downward, size: 16, color: colors.accent),
                  const SizedBox(width: 6),
                  Text(
                    'Jump to latest',
                    style: TextStyle(
                      fontFamily: colors.mono,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: fgColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
