import 'package:flutter/material.dart';

class TimestampRevealController extends ChangeNotifier {
  late final AnimationController _controller;
  double _dragOffset = 0;
  bool _isDragging = false;

  static const double _maxReveal = 48.0;

  TimestampRevealController(TickerProvider vsync) {
    _controller = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 200),
    )..addListener(() => notifyListeners());
  }

  double get revealFraction {
    if (_isDragging) return (-_dragOffset / _maxReveal).clamp(0.0, 1.0);
    return _controller.value;
  }

  void onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) {
      _isDragging = true;
      _controller.stop();
    }
    _dragOffset += details.delta.dx;
    _dragOffset = _dragOffset.clamp(-_maxReveal, 0.0);
    notifyListeners();
  }

  void onPanEnd(DragEndDetails details) {
    _isDragging = false;
    _dragOffset = 0;
    _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
