import 'package:flutter/material.dart';
import 'package:samantha/common/extensions/context_x.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:samantha/features/chat/presentation/widgets/code_block.dart';
import 'package:samantha/features/chat/presentation/widgets/pulse_dot.dart';
import 'package:samantha/features/chat/presentation/widgets/terminal_cursor.dart';
import 'package:samantha/features/chat/presentation/widgets/thinking_block.dart';
import 'package:samantha/features/chat/presentation/widgets/tool_result_chip.dart';

class _ContentSegment {
  final String text;
  final bool isCode;
  final String language;

  const _ContentSegment({
    required this.text,
    required this.isCode,
    this.language = '',
  });
}

class ChatMessageContent extends StatelessWidget {
  final String messageId;
  final String content;
  final String thinkingContent;
  final Duration? thinkingDuration;
  final bool isStreaming;
  final List<ToolResult> toolResults;
  final List<ChatImage> images;

  const ChatMessageContent({
    super.key,
    required this.messageId,
    required this.content,
    this.thinkingContent = '',
    this.thinkingDuration,
    required this.isStreaming,
    this.toolResults = const [],
    this.images = const [],
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

    for (final image in images) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              image.url,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 100,
                  alignment: Alignment.center,
                  child: Text(
                    'Failed to load image',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              },
            ),
          ),
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
                ShimmerText(
                  context.l10n.thinking,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(child: Text(content)),
              if (isStreaming) ...[
                const SizedBox(width: 2),
                const TerminalCursor(),
              ],
            ],
          ),
        );
      } else {
        children.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final seg in segments)
                if (seg.isCode)
                  CodeBlock(
                    key: ValueKey('code-${seg.text.hashCode}'),
                    code: seg.text,
                    language: seg.language,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(seg.text),
                  ),
              if (isStreaming)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: TerminalCursor(),
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
        final lang = trimmed.substring(0, firstLineEnd).trim().toLowerCase();
        final code = trimmed.substring(firstLineEnd + 1).trimRight();
        if (code.isEmpty) continue;
        segments.add(_ContentSegment(text: code, isCode: true, language: lang));
      } else {
        if (parts[i].trim().isNotEmpty) {
          segments.add(_ContentSegment(text: parts[i].trim(), isCode: false));
        }
      }
    }

    return segments;
  }
}
