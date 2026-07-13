import 'package:flutter/material.dart';
import 'package:samantha/app/theme.dart';

class TerminalCursor extends StatefulWidget {
  const TerminalCursor({super.key});

  @override
  State<TerminalCursor> createState() => _TerminalCursorState();
}

class _TerminalCursorState extends State<TerminalCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _controller.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final visible = _controller.value < 0.5;
        return Opacity(
          opacity: visible ? 1.0 : 0.0,
          child: Container(
            width: 8,
            height: 16,
            margin: const EdgeInsets.only(left: 2, bottom: 2),
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      },
    );
  }
}
