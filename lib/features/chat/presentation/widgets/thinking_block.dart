import 'package:flutter/material.dart';
import 'package:samantha/features/chat/presentation/widgets/collapsible_block.dart';

const _shimmerPeriod = Duration(milliseconds: 1100);

/// Text with a band of light sweeping across the glyphs, used to signal that the
/// model is still working. Falls back to plain text when the platform asks for
/// reduced motion.
class ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const ShimmerText(this.text, {super.key, this.style});

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _shimmerPeriod,
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
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
    final colorScheme = Theme.of(context).colorScheme;
    final style = (widget.style ?? const TextStyle()).copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final label = Text(widget.text, style: style);

    if (_reduceMotion) return label;

    return AnimatedBuilder(
      animation: _controller,
      child: label,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final travel = bounds.width * 1.7;
            final offset = -bounds.width * 0.7 + travel * _controller.value;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                colorScheme.onSurface,
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromLTWH(offset, 0, bounds.width * 0.7, bounds.height),
            );
          },
          child: child,
        );
      },
    );
  }
}

/// The model's reasoning for one turn, collapsed behind a tappable label.
class ThinkingBlock extends StatelessWidget {
  final String text;
  final bool isThinking;
  final Duration? duration;

  const ThinkingBlock({
    super.key,
    required this.text,
    required this.isThinking,
    this.duration,
  });

  static String _formatDuration(Duration d) {
    if (d.inMinutes >= 1) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
  }

  String get _label {
    if (isThinking) return 'Thinking…';
    final d = duration;
    if (d == null || d == Duration.zero) return 'Thought';
    return 'Thought for ${_formatDuration(d)}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CollapsibleBlock(
      icon: Icons.psychology,
      label: isThinking
          ? ShimmerText(_label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))
          : Text(
              _label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
            ),
      child: SelectableText(
        text.trimRight(),
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
