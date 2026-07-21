import 'package:flutter/material.dart';
import 'package:samantha/app/theme.dart';

const _animationDuration = Duration(milliseconds: 200);

class CollapsibleBlock extends StatefulWidget {
  final IconData icon;
  final Widget label;
  final Widget child;
  final bool initialExpanded;
  final Color? backgroundColor;
  final Color? borderColor;
  final String? summary;

  const CollapsibleBlock({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
    this.initialExpanded = false,
    this.backgroundColor,
    this.borderColor,
    this.summary,
  });

  @override
  State<CollapsibleBlock> createState() => _CollapsibleBlockState();
}

class _CollapsibleBlockState extends State<CollapsibleBlock> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.borderColor ?? theme.colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Icon(widget.icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Flexible(
                    child: DefaultTextStyle.merge(
                      child: widget.label,
                      style: TextStyle(
                        fontFamily: colors.mono,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (!_expanded && widget.summary != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      widget.summary!,
                      style: TextStyle(
                        fontFamily: colors.mono,
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: _animationDuration,
                    child: Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: _animationDuration,
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 10, 8),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        fontFamily: colors.mono,
                        fontSize: 12,
                        height: 1.4,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      child: widget.child,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
