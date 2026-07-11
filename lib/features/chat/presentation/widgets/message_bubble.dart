import 'package:flutter/material.dart';
import 'package:samantha/features/chat/domain/chat_message_formatting.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:samantha/features/chat/presentation/widgets/chat_message_content.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isUser;

  const MessageBubble({required this.msg, required this.isUser, super.key});

  @override
  Widget build(BuildContext context) {
    final footerParts = msg.buildFooterParts();

    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: isUser ? Theme.of(context).colorScheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(12.0),
          ),
          constraints: isUser ? BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75) : null,
          child: ChatMessageContent(
            messageId: msg.id,
            content: msg.content,
            thinkingContent: msg.thinkingContent,
            thinkingDuration: msg.thinkingDuration,
            isStreaming: msg.isStreaming,
            toolResults: msg.toolResults,
          ),
        ),
        if (!isUser && footerParts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 2),
            child: Text(
              footerParts.join(' \u00B7 '),
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}