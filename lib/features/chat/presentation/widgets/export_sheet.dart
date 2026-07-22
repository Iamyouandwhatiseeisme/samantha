import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:samantha/common/extensions/context_x.dart';
import 'package:samantha/features/chat/domain/conversation_exporter.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:share_plus/share_plus.dart';

class ExportSheet extends StatelessWidget {
  final List<ChatMessage> messages;

  const ExportSheet({required this.messages});

  Future<void> _export(BuildContext context, ExportFormat format) async {
    final content = ConversationExporter.export(messages, format: format);
    await SharePlus.instance.share(
      ShareParams(
        text: content,
        subject: 'Conversation Export',
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context, ExportFormat format) async {
    final content = ConversationExporter.export(messages, format: format);
    await Clipboard.setData(ClipboardData(text: content));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.codeCopied),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.exportConversation,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _ExportOption(
              icon: Icons.code,
              label: context.l10n.exportAsMarkdown,
              onTap: () => _export(context, ExportFormat.markdown),
              onCopy: () => _copyToClipboard(context, ExportFormat.markdown),
            ),
            const SizedBox(height: 8),
            _ExportOption(
              icon: Icons.text_fields,
              label: context.l10n.exportAsText,
              onTap: () => _export(context, ExportFormat.plainText),
              onCopy: () => _copyToClipboard(context, ExportFormat.plainText),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  const _ExportOption({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: onCopy,
              tooltip: 'Copy to clipboard',
            ),
          ],
        ),
      ),
    );
  }
}
