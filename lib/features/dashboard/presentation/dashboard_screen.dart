import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:samantha/app/router.dart';
import 'package:samantha/app/theme.dart';

@RoutePage()
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _drawController;
  late final AnimationController _glowController;
  bool _drawingComplete = false;

  @override
  void initState() {
    super.initState();
    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _drawController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _drawingComplete = true);
        _glowController.repeat(reverse: true);
        _navigateToNext();
      }
    });

    _drawController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _drawController.value = 1.0;
      setState(() => _drawingComplete = true);
    }
  }

  @override
  void dispose() {
    _drawController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    context.router.replace(const ConnectionSettingsRoute());
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_drawController, _glowController]),
          builder: (context, _) {
            final progress = _drawingComplete ? 1.0 : _drawController.value;
            return CustomPaint(
              size: const Size(200, 300),
              painter: _SPainter(
                progress: progress,
                glowProgress: _drawingComplete ? _glowController.value : 0.0,
                color: colors.accent,
                strokeWidth: 7,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SPainter extends CustomPainter {
  final double progress;
  final double glowProgress;
  final Color color;
  final double strokeWidth;

  const _SPainter({
    required this.progress,
    required this.glowProgress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.75, h * 0.1)
      ..cubicTo(w * 0.25, h * -0.05, w * 0.1, h * 0.3, w * 0.22, h * 0.35)
      ..cubicTo(w * 0.35, h * 0.4, w * 0.85, h * 0.42, w * 0.8, h * 0.52)
      ..cubicTo(w * 0.75, h * 0.62, w * 0.2, h * 0.55, w * 0.2, h * 0.65)
      ..cubicTo(w * 0.2, h * 0.75, w * 0.85, h * 0.8, w * 0.78, h * 0.92)
      ..cubicTo(w * 0.7, h * 1.05, w * 0.15, h * 0.95, w * 0.22, h * 0.9)
      ..cubicTo(w * 0.3, h * 0.85, w * 0.35, h * 0.88, w * 0.3, h * 0.88);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      final extractedPath = metric.extractPath(0, metric.length * progress);
      canvas.drawPath(extractedPath, paint);
    }

    if (glowProgress > 0) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.25 * glowProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

      for (final metric in metrics) {
        canvas.drawPath(metric.extractPath(0, metric.length), glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glowProgress != glowProgress;
  }
}
