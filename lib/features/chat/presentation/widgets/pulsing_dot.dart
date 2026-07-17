import 'package:flutter/material.dart';

class PulsingDot extends StatefulWidget {
  final Color color;
  const PulsingDot({required this.color, super.key});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Opacity(
          opacity: 0.4 + 0.6 * _controller.value,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
          ),
        );
      },
    );
  }
}
