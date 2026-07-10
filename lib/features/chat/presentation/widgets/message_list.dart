import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/chat/presentation/widgets/chat_message_content.dart';
import 'package:samantha/features/chat/presentation/widgets/tool_status_banner.dart';

class MessageList extends StatelessWidget {
  final ScrollController scrollController;
  final AnimationController revealController;

  const MessageList({super.key, required this.scrollController, required this.revealController});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatCubit>().state;
    final messages = state.messages;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isUser = msg.role == ChatRole.user;
              final bubble = _buildBubble(context, msg, isUser);

              return AnimatedBuilder(
                animation: revealController,
                builder: (context, _) {
                  final fraction = revealController.value;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(right: fraction * 48),
                          child: bubble,
                        ),
                      ),
                      Positioned(
                        right: (fraction - 1) * 48,
                        bottom: 4,
                        child: Opacity(
                          opacity: fraction,
                          child: Text(
                            _formatTime(msg.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        if (state.currentToolName != null)
          ToolStatusBanner(
            tool: state.currentToolName!,
            status: state.currentToolStatus ?? state.currentToolName!,
          ),
      ],
    );
  }

  Widget _buildBubble(BuildContext context, ChatMessage msg, bool isUser) {
    final footerParts = <String>[];
    if (msg.inputTokens != null || msg.outputTokens != null) {
      final total = (msg.inputTokens ?? 0) + (msg.outputTokens ?? 0);
      if (total > 0) {
        footerParts.add('${_formatTokenCount(total)} tokens');
      }
    }
    if (msg.cost != null && msg.cost! > 0) {
      footerParts.add('\$${msg.cost!.toStringAsFixed(4)}');
    }
    if (msg.duration != null && msg.duration!.inSeconds > 0) {
      footerParts.add(_formatDuration(msg.duration!));
    }

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
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatTokenCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }
}
