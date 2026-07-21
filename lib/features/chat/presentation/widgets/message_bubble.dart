import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/common/extensions/context_x.dart';
import 'package:samantha/features/chat/domain/chat_message_formatting.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/chat/presentation/widgets/chat_message_content.dart';
import 'package:samantha/features/chat/presentation/widgets/copy_icon.dart';
import 'package:samantha/features/chat/presentation/widgets/message_action_menu.dart';
import 'package:samantha/features/chat/presentation/widgets/message_edit_dialog.dart';

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

  void _showActionMenu(TapDownDetails details) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset position = details.globalPosition;

    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'Message actions',
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
            Positioned(
              left: _clampX(position.dx - 90, overlay.size.width),
              top: _clampY(position.dy - 20, overlay.size.height),
              child: MessageActionMenu(
                message: widget.msg,
                isUser: widget.isUser,
                onRetry: () {
                  Navigator.of(ctx).pop();
                  context.read<ChatCubit>().retryMessage(widget.msg.id);
                },
                onEdit: () {
                  Navigator.of(ctx).pop();
                  _showEditDialog();
                },
                onCopyCode: () {
                  Navigator.of(ctx).pop();
                  _copyCodeBlocks();
                },
                onBranch: () {
                  Navigator.of(ctx).pop();
                  context.read<ChatCubit>().branchFromMessage(widget.msg.id);
                },
              ),
            ),
          ],
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut)),
            child: child,
          ),
        );
      },
    );
  }

  double _clampX(double x, double maxWidth) {
    return x.clamp(8.0, maxWidth - 188.0);
  }

  double _clampY(double y, double maxHeight) {
    return y.clamp(8.0, maxHeight - 200.0);
  }

  void _showEditDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => MessageEditDialog(
        initialContent: widget.msg.content,
        onSave: (newContent) {
          context.read<ChatCubit>().editMessage(widget.msg.id, newContent);
        },
      ),
    );
  }

  void _copyCodeBlocks() {
    final codeBlocks = _extractCodeBlocks(widget.msg.content);
    if (codeBlocks.isEmpty) return;

    final codeText = codeBlocks.join('\n\n');
    Clipboard.setData(ClipboardData(text: codeText));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.codeCopied,
          style: TextStyle(fontFamily: AppColors.of(context).mono, fontSize: 12),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<String> _extractCodeBlocks(String content) {
    if (!content.contains('```')) return [];

    final parts = content.split('```');
    final blocks = <String>[];

    for (int i = 0; i < parts.length; i++) {
      if (i.isOdd) {
        final trimmed = parts[i];
        final firstLineEnd = trimmed.indexOf('\n');
        if (firstLineEnd == -1) {
          blocks.add('```${trimmed.trim()}```');
        } else {
          final lang = trimmed.substring(0, firstLineEnd).trim();
          final code = trimmed.substring(firstLineEnd + 1).trim();
          if (code.isNotEmpty) {
            blocks.add('```$lang\n$code\n```');
          }
        }
      }
    }

    return blocks;
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
                onLongPressStart: (_) => _showActionMenu(TapDownDetails(globalPosition: Offset.zero)),
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
                    images: msg.images,
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
