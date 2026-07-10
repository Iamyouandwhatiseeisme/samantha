import 'package:flutter/material.dart';

const _animationDuration = Duration(milliseconds: 200);
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
            // Slide a soft highlight from just off the left edge to just off the
            // right, so the sweep leaves and re-enters cleanly on every loop.
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
///
/// It never opens or closes itself: while the model reasons the label shimmers
/// "Thinking…", and once the answer starts it settles into "Thought for 3.2s".
/// Expanding is always the reader's choice.
class ThinkingBlock extends StatefulWidget {
  final String text;
  final bool isThinking;
  final Duration? duration;

  const ThinkingBlock({
    super.key,
    required this.text,
    required this.isThinking,
    this.duration,
  });

  @override
  State<ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<ThinkingBlock> {
  bool _expanded = false;

  static String _formatDuration(Duration d) {
    if (d.inMinutes >= 1) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
  }

  String get _label {
    if (widget.isThinking) return 'Thinking…';
    final duration = widget.duration;
    if (duration == null || duration == Duration.zero) return 'Thought';
    return 'Thought for ${_formatDuration(duration)}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const labelStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
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
                  Icon(Icons.psychology, size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  if (widget.isThinking)
                    ShimmerText(_label, style: labelStyle)
                  else
                    Text(
                      _label,
                      style: labelStyle.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
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
          // Only build the reasoning when it is on screen. A cross-fade would keep
          // the full transcript laid out behind the collapsed header and re-run
          // that layout on every streamed delta.
          AnimatedSize(
            duration: _animationDuration,
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(26, 0, 8, 8),
                    child: SelectableText(
                      widget.text.trimRight(),
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
