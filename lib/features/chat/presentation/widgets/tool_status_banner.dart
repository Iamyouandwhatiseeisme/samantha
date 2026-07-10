import 'package:flutter/material.dart';

class ToolStatusBanner extends StatelessWidget {
  final String tool;
  final String status;
  const ToolStatusBanner({super.key, required this.tool, required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Icon(Icons.build, size: 14, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              status,
              style: TextStyle(fontSize: 12, color: colorScheme.onSecondaryContainer),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
