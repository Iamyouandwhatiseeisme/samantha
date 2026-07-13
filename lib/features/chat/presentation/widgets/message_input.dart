import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/chat/presentation/state/chat_state.dart';

class MessageInput extends StatelessWidget {
  final TextEditingController inputController;

  const MessageInput({super.key, required this.inputController});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        final isConnected = state.connectionStatus != ChatConnectionStatus.disconnected;
        final isStreaming = state.connectionStatus == ChatConnectionStatus.streaming;
        final hasText = state.inputText.trim().isNotEmpty;
        final repoName = state.currentProjectPath?.split('/').last;

        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.5),
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (repoName != null || state.selectedModel != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          height: 28,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              if (repoName != null)
                                _ContextChip(
                                  icon: Icons.folder_outlined,
                                  label: repoName,
                                  mono: true,
                                ),
                              if (repoName != null && state.selectedModel != null)
                                const SizedBox(width: 6),
                              if (state.selectedModel != null)
                                _ContextChip(
                                  icon: Icons.memory,
                                  label: _modelLabel(state.selectedModel!),
                                ),
                            ],
                          ),
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: inputController,
                            enabled: isConnected,
                            minLines: 1,
                            maxLines: 6,
                            decoration: InputDecoration(
                              hintText: 'Message\u2026',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainer,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outlineVariant,
                                  width: 0.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outlineVariant,
                                  width: 0.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: colors.accent, width: 1),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: theme.colorScheme.onSurface,
                            ),
                            onChanged: (text) => context.read<ChatCubit>().updateInput(text),
                            onSubmitted: isConnected ? (_) => _send(context) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 44,
                          height: 46,
                          child: isStreaming
                              ? ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: colors.error,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                  ),
                                  onPressed: () => context.read<ChatCubit>().stopGeneration(),
                                  child: const Icon(
                                    Icons.stop,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                )
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: hasText && isConnected
                                        ? colors.accent
                                        : theme.colorScheme.surfaceContainerHigh,
                                    foregroundColor: hasText && isConnected
                                        ? Colors.white
                                        : theme.colorScheme.onSurfaceVariant,
                                    elevation: 0,
                                  ),
                                  onPressed: isConnected ? () => _send(context) : null,
                                  child: Icon(
                                    Icons.send,
                                    size: 18,
                                    color: hasText && isConnected
                                        ? Colors.white
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _modelLabel(String qualifiedId) {
    final parts = qualifiedId.split('/');
    return parts.length > 1 ? parts.last : qualifiedId;
  }

  void _send(BuildContext context) {
    context.read<ChatCubit>().sendMessage();
    inputController.clear();
  }
}

class _ContextChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool mono;

  const _ContextChip({required this.icon, required this.label, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: mono ? colors.mono : null,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
