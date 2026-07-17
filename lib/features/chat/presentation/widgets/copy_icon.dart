import 'package:flutter/material.dart';
import 'package:samantha/app/theme.dart';

class CopyIcon extends StatelessWidget {
  final bool visible;
  final bool copied;
  final VoidCallback onTap;

  const CopyIcon({
    required this.visible,
    required this.copied,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !visible,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 7, left: 6, right: 6),
          child: GestureDetector(
            onTap: onTap,
            child: Icon(
              copied ? Icons.check : Icons.copy,
              size: 15,
              color: copied ? colors.success : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
