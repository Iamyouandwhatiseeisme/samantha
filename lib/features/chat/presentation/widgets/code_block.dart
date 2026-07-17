import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/features/chat/presentation/widgets/highlighted_diff_line.dart';

class CodeBlock extends StatefulWidget {
  final String code;
  final String language;

  const CodeBlock({required this.code, required this.language, super.key});

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final isDiff = widget.language == 'diff';
    final lines = widget.code.split('\n');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colors.codeSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.codeBorder, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              border: Border(
                bottom: BorderSide(color: colors.codeBorder, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.language == 'bash' || widget.language == 'sh' || widget.language == 'shell'
                      ? Icons.terminal
                      : Icons.code,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.language.isNotEmpty ? widget.language : 'code',
                  style: TextStyle(
                    fontFamily: colors.mono,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: widget.code));
                    setState(() => _copied = true);
                    Future.delayed(const Duration(milliseconds: 1500), () {
                      if (mounted) setState(() => _copied = false);
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check : Icons.copy,
                          size: 14,
                          color: _copied ? colors.success : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _copied ? 'Copied' : 'Copy',
                          style: TextStyle(
                            fontFamily: colors.mono,
                            fontSize: 10,
                            color: _copied ? colors.success : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: isDiff
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: lines.map((line) => HighlightedDiffLine(line: line, colors: colors)).toList(),
                    )
                  : SelectableText(
                      widget.code,
                      style: TextStyle(
                        fontFamily: colors.mono,
                        fontSize: 13,
                        height: 1.5,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

}

