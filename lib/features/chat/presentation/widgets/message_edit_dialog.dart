import 'package:flutter/material.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/common/extensions/context_x.dart';

class MessageEditDialog extends StatefulWidget {
  final String initialContent;
  final ValueChanged<String> onSave;

  const MessageEditDialog({
    required this.initialContent,
    required this.onSave,
    super.key,
  });

  @override
  State<MessageEditDialog> createState() => _MessageEditDialogState();
}

class _MessageEditDialogState extends State<MessageEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        context.l10n.editMessageTitle,
        style: TextStyle(fontFamily: colors.mono, fontSize: 14, fontWeight: FontWeight.w600),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
          minWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: TextField(
          controller: _controller,
          maxLines: null,
          minLines: 3,
          autofocus: true,
          style: TextStyle(
            fontFamily: colors.mono,
            fontSize: 13,
            height: 1.5,
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.accent, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.editMessageCancel),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) {
              widget.onSave(text);
              Navigator.of(context).pop();
            }
          },
          child: Text(context.l10n.editMessageSave),
        ),
      ],
    );
  }
}
