import 'package:flutter/material.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:samantha/features/chat/presentation/widgets/pulse_dot.dart';
import 'package:samantha/features/chat/presentation/widgets/thinking_block.dart';
import 'package:samantha/features/chat/presentation/widgets/tool_result_chip.dart';

class _ContentSegment {
  final String text;
  final bool isCode;
  const _ContentSegment({required this.text, required this.isCode});
}

class ChatMessageContent extends StatelessWidget {
  final String messageId;
  final String content;
  final String thinkingContent;
  final Duration? thinkingDuration;
  final bool isStreaming;
  final List<ToolResult> toolResults;

  const ChatMessageContent({
    super.key,
    required this.messageId,
    required this.content,
    this.thinkingContent = '',
    this.thinkingDuration,
    required this.isStreaming,
    this.toolResults = const [],
  });

  @override
  Widget build(BuildContext context) {
    final hasThinking = thinkingContent.isNotEmpty;
    final isThinking = isStreaming && content.isEmpty;

    final children = <Widget>[];

    if (hasThinking) {
      children.add(
        ThinkingBlock(
          key: ValueKey('thinking-$messageId'),
          text: thinkingContent,
          isThinking: isThinking,
          duration: thinkingDuration,
        ),
      );
    }

    if (isThinking) {
      if (!hasThinking) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PulseDot(),
                const SizedBox(width: 8),
                const ShimmerText(
                  'Thinking…',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      }
    } else if (content.isNotEmpty) {
      final segments = _parseContent(content);

      if (segments.isEmpty) {
        children.add(
          isStreaming
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(child: Text(content)),
                    const SizedBox(width: 4),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                )
              : Text(content),
        );
      } else {
        children.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final seg in segments)
                if (seg.isCode)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: _CollapsibleCodeBlock(code: seg.text),
                  )
                else
                  Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Text(seg.text)),
              if (isStreaming)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        );
      }
    }

    for (final result in toolResults) {
      children.add(ToolResultChip(result: result));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  List<_ContentSegment> _parseContent(String text) {
    if (!text.contains('```')) return [];

    final parts = text.split('```');
    final segments = <_ContentSegment>[];

    for (int i = 0; i < parts.length; i++) {
      if (i.isOdd) {
        final trimmed = parts[i];
        final firstLineEnd = trimmed.indexOf('\n');
        if (firstLineEnd == -1) {
          segments.add(_ContentSegment(text: '```$trimmed```', isCode: false));
          continue;
        }
        final lang = trimmed.substring(0, firstLineEnd).trim();
        if (lang == 'sh' || lang == 'bash') {
          final code = trimmed.substring(firstLineEnd + 1);
          segments.add(_ContentSegment(text: code, isCode: true));
        } else {
          segments.add(_ContentSegment(text: '```$trimmed```', isCode: false));
        }
      } else {
        if (parts[i].isNotEmpty) {
          segments.add(_ContentSegment(text: parts[i], isCode: false));
        }
      }
    }

    return segments;
  }
}

class _CollapsibleCodeBlock extends StatefulWidget {
  final String code;
  const _CollapsibleCodeBlock({required this.code});

  @override
  State<_CollapsibleCodeBlock> createState() => _CollapsibleCodeBlockState();
}

class _CollapsibleCodeBlockState extends State<_CollapsibleCodeBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.terminal, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Shell Command',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                widget.code,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
