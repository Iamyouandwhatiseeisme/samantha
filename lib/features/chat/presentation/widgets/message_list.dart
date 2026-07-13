import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/chat/presentation/widgets/message_bubble.dart';
import 'package:samantha/features/chat/presentation/widgets/scroll_to_bottom_fab.dart';
import 'package:samantha/features/chat/presentation/widgets/tool_status_banner.dart';

class MessageList extends StatefulWidget {
  final ScrollController scrollController;
  final AnimationController revealController;

  const MessageList({super.key, required this.scrollController, required this.revealController});

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  late final ValueNotifier<bool> _showScrollToBottom;

  @override
  void initState() {
    super.initState();
    _showScrollToBottom = ValueNotifier(false);
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _showScrollToBottom.dispose();
    super.dispose();
  }

  void _onScroll() {
    final controller = widget.scrollController;
    if (!controller.hasClients) return;
    final maxScroll = controller.position.maxScrollExtent;
    final currentScroll = controller.position.pixels;
    final visible = maxScroll - currentScroll > 200;
    if (_showScrollToBottom.value != visible) {
      _showScrollToBottom.value = visible;
    }
  }

  void _scrollToBottom() {
    final controller = widget.scrollController;
    if (!controller.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;
      final target = controller.position.maxScrollExtent;
      if ((target - controller.position.pixels).abs() < 2) return;

      controller
          .animateTo(
            target,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          )
          .then((_) {
        if (controller.hasClients &&
            (controller.position.maxScrollExtent - controller.position.pixels).abs() > 2) {
          controller.animateTo(
            controller.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });
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
                              child: MessageBubble(msg: msg, isUser: isUser),
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
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: ScrollToBottomFab(
                  showScrollToBottom: _showScrollToBottom,
                  onPressed: _scrollToBottom,
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
