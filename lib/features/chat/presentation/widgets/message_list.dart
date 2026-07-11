import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/chat/presentation/widgets/chat_message_content.dart';
import 'package:samantha/features/chat/presentation/widgets/tool_status_banner.dart';

class MessageList extends StatefulWidget {
  final ScrollController scrollController;
  final AnimationController revealController;

  const MessageList({super.key, required this.scrollController, required this.revealController});

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final controller = widget.scrollController;
    if (!controller.hasClients) return;
    final maxScroll = controller.position.maxScrollExtent;
    final currentScroll = controller.position.pixels;
    final show = maxScroll - currentScroll > 200;
    if (show != _showScrollToBottom) {
      setState(() => _showScrollToBottom = show);
    }
  }

  void _scrollToBottom() {
    widget.scrollController.animateTo(
      widget.scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatCubit>().state;
    final messages = state.messages;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isUser = msg.role == ChatRole.user;

                  return AnimatedBuilder(
                    animation: widget.revealController,
                    builder: (context, _) {
                      final fraction = widget.revealController.value;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(right: fraction * 48),
                              child: _MessageBubble(msg: msg, isUser: isUser),
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
              if (_showScrollToBottom)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _scrollToBottom,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_downward,
                              size: 18,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Scroll to bottom',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isUser;

  const _MessageBubble({required this.msg, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final footerParts = _buildFooterParts();

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

  List<String> _buildFooterParts() {
    final parts = <String>[];
    if (msg.inputTokens != null || msg.outputTokens != null) {
      final total = (msg.inputTokens ?? 0) + (msg.outputTokens ?? 0);
      if (total > 0) {
        parts.add('${_formatTokenCount(total)} tokens');
      }
    }
    if (msg.cost != null && msg.cost! > 0) {
      parts.add('\$${msg.cost!.toStringAsFixed(4)}');
    }
    if (msg.duration != null && msg.duration!.inSeconds > 0) {
      parts.add(_formatDuration(msg.duration!));
    }
    return parts;
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
