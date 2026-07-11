import 'dart:ui';

import 'package:flutter/material.dart';

class ScrollToBottomButton extends StatelessWidget {
  const ScrollToBottomButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.colorScheme.surfaceContainerHighest;
    final fgColor = theme.colorScheme.onSurface;

    return Center(
      child: GestureDetector(
        onTap: onPressed,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 18),
              decoration: BoxDecoration(
                color: bgColor.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.all(Radius.circular(100)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_downward, size: 18, color: fgColor),
                  const SizedBox(width: 6),
                  Text(
                    'Scroll to bottom',
                    style: TextStyle(
                      color: fgColor,
                      fontWeight: FontWeight.w500,
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