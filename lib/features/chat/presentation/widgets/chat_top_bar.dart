import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/common/extensions/context_x.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/chat/presentation/state/chat_state.dart';
import 'package:samantha/features/chat/presentation/widgets/export_sheet.dart';

class ChatTopBar extends StatelessWidget {
  const ChatTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.5),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Row(
              children: [
                ChatIconButton(icon: Icons.arrow_back, onPressed: () => context.router.pop()),
                Expanded(
                  child: BlocBuilder<ChatCubit, ChatState>(
                    builder: (context, state) {
                      final title = state.sessionName ?? context.l10n.fallbackSessionTitle;
                      final lastActivity = state.lastActivity;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: colors.mono,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (lastActivity != null)
                            Text(
                              lastActivity,
                              style: TextStyle(
                                fontFamily: colors.mono,
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                ChatIconButton(
                  icon: Icons.refresh,
                  onPressed: () => context.read<ChatCubit>().connect(),
                ),
                BlocBuilder<ChatCubit, ChatState>(
                  builder: (context, state) {
                    final hasMessages = state.messages.isNotEmpty;
                    return ChatIconButton(
                      icon: Icons.share,
                      onPressed: hasMessages
                          ? () => showModalBottomSheet(
                                context: context,
                                builder: (_) => ExportSheet(messages: state.messages),
                              )
                          : null,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChatIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const ChatIconButton({required this.icon, this.onPressed, super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      constraints: const BoxConstraints(minWidth: 36, maxWidth: 36, minHeight: 36, maxHeight: 36),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }
}
