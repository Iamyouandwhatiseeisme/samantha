import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/features/chat/domain/chat_message_formatting.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:samantha/features/chat/presentation/widgets/chat_message_content.dart';
import 'package:samantha/features/chat/presentation/widgets/copy_icon.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage msg;
  final bool isUser;

  const MessageBubble({required this.msg, required this.isUser, super.key});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showCopy = false;
  bool _copied = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _revealCopy() {
    _hideTimer?.cancel();
    setState(() {
      _showCopy = true;
      _copied = false;
    });
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showCopy = false);
    });
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.msg.content));
    setState(() => _copied = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showCopy = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final msg = widget.msg;
    final isUser = widget.isUser;
    final footerParts = msg.buildFooterParts();
    final maxWidth = MediaQuery.of(context).size.width * 0.76;
    final hasContent = msg.content.isNotEmpty;
    final copyVisible = _showCopy && hasContent;

    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUser) CopyIcon(visible: copyVisible, copied: _copied, onTap: _copy),
            Flexible(
              child: GestureDetector(
                onTap: hasContent ? _revealCopy : null,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? colors.userSurface : colors.agentSurface,
                    borderRadius: isUser
                        ? const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(4),
                          )
                        : const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(4),
                            bottomRight: Radius.circular(16),
                          ),
                    border: Border.all(
                      color: isUser ? colors.userBorder : colors.agentBorder,
                      width: 0.5,
                    ),
                  ),
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: ChatMessageContent(
                    messageId: msg.id,
                    content: msg.content,
                    thinkingContent: msg.thinkingContent,
                    thinkingDuration: msg.thinkingDuration,
                    isStreaming: msg.isStreaming,
                    toolResults: msg.toolResults,
                  ),
                ),
              ),
            ),
            if (!isUser) CopyIcon(visible: copyVisible, copied: _copied, onTap: _copy),
          ],
        ),
        if (!isUser && footerParts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2),
            child: Text(
              footerParts.join('  \u00B7  '),
              style: TextStyle(
                fontFamily: colors.mono,
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

