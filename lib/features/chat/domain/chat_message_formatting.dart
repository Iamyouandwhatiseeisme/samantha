import 'package:samantha/features/chat/domain/entities.dart';

extension ChatMessageFormatting on ChatMessage {
  List<String> buildFooterParts() {
    final parts = <String>[];
    if (inputTokens != null || outputTokens != null) {
      final total = (inputTokens ?? 0) + (outputTokens ?? 0);
      if (total > 0) {
        parts.add('${_formatTokenCount(total)} tokens');
      }
    }
    if (cost != null && cost! > 0) {
      parts.add('\$${cost!.toStringAsFixed(4)}');
    }
    if (duration != null && duration!.inSeconds > 0) {
      parts.add(_formatDuration(duration!));
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