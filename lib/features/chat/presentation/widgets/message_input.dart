import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/common/extensions/context_x.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/chat/presentation/state/chat_state.dart';
import 'package:samantha/features/chat/presentation/widgets/model_text_field.dart';
import 'package:samantha/features/chat/presentation/widgets/status_dot.dart';

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
        final hasAttachments = state.attachments.isNotEmpty;

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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const StatusDot(),
                          const SizedBox(width: 8),
                          const Expanded(child: ModelTextField()),
                        ],
                      ),
                    ),
                    if (hasAttachments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: state.attachments.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 6),
                            itemBuilder: (context, index) {
                              final attachment = state.attachments[index];
                              return _AttachmentChip(
                                attachment: attachment,
                                onRemove: () => context.read<ChatCubit>().removeAttachment(index),
                              );
                            },
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
                              hintText: context.l10n.messageHint,
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
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(left: 4, right: 8),
                                child: IconButton(
                                  icon: const Icon(Icons.attach_file, size: 20),
                                  onPressed: isConnected && !isStreaming
                                      ? () => _pickFile(context)
                                      : null,
                                  tooltip: 'Attach file',
                                  color: theme.colorScheme.onSurfaceVariant,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(),
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
                                    backgroundColor: (hasText || hasAttachments) && isConnected
                                        ? colors.accent
                                        : theme.colorScheme.surfaceContainerHigh,
                                    foregroundColor: (hasText || hasAttachments) && isConnected
                                        ? Colors.white
                                        : theme.colorScheme.onSurfaceVariant,
                                    elevation: 0,
                                  ),
                                  onPressed: isConnected ? () => _send(context) : null,
                                  child: Icon(
                                    Icons.send,
                                    size: 18,
                                    color: (hasText || hasAttachments) && isConnected
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

  Future<void> _pickFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      for (final file in result.files) {
        if (file.bytes == null || file.name.isEmpty) continue;

        final mimeType = _guessMimeType(file.name);
        final attachment = PendingAttachment(
          name: file.name,
          mimeType: mimeType,
          base64Data: base64Encode(file.bytes!),
          sizeBytes: file.size,
        );

        context.read<ChatCubit>().addAttachment(attachment);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick file: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _guessMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'svg' => 'image/svg+xml',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'json' => 'application/json',
      'xml' => 'application/xml',
      'csv' => 'text/csv',
      'md' => 'text/markdown',
      'html' || 'htm' => 'text/html',
      'css' => 'text/css',
      'js' => 'text/javascript',
      'ts' => 'text/typescript',
      'py' => 'text/x-python',
      'rb' => 'text/x-ruby',
      'java' => 'text/x-java',
      'go' => 'text/x-go',
      'rs' => 'text/x-rust',
      'cpp' || 'cc' || 'cxx' => 'text/x-c++',
      'c' => 'text/x-c',
      'h' => 'text/x-c',
      'swift' => 'text/x-swift',
      'kt' => 'text/x-kotlin',
      'dart' => 'text/x-dart',
      'sh' || 'bash' => 'text/x-sh',
      'yaml' || 'yml' => 'text/yaml',
      'toml' => 'text/toml',
      _ => 'application/octet-stream',
    };
  }

  void _send(BuildContext context) {
    context.read<ChatCubit>().sendMessage();
    inputController.clear();
  }
}

class _AttachmentChip extends StatelessWidget {
  final PendingAttachment attachment;
  final VoidCallback onRemove;

  const _AttachmentChip({required this.attachment, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final isImage = attachment.mimeType.startsWith('image/');
    final sizeLabel = _formatSize(attachment.sizeBytes);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isImage ? Icons.image : Icons.insert_drive_file,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 120),
            child: Text(
              attachment.name,
              style: TextStyle(
                fontFamily: colors.mono,
                fontSize: 10,
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            sizeLabel,
            style: TextStyle(
              fontFamily: colors.mono,
              fontSize: 9,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.close,
                size: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
