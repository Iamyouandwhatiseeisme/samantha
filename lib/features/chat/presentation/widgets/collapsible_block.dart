import 'package:flutter/material.dart';

const _animationDuration = Duration(milliseconds: 200);

class CollapsibleBlock extends StatefulWidget {
  final IconData icon;
  final Widget label;
  final Widget child;
  final bool initialExpanded;
  final Color? backgroundColor;
  final Color? borderColor;

  const CollapsibleBlock({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
    this.initialExpanded = false,
    this.backgroundColor,
    this.borderColor,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.borderColor ?? colorScheme.outlineVariant.withValues(alpha: 0.5),
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
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(widget.icon, size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Flexible(child: DefaultTextStyle.merge(child: widget.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: _animationDuration,
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
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
                    padding: const EdgeInsets.fromLTRB(26, 0, 8, 8),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
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
