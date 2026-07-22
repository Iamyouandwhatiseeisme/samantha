import 'package:samantha/features/chat/domain/entities.dart';

enum ExportFormat { markdown, plainText }

class ConversationExporter {
  static String export(List<ChatMessage> messages, {ExportFormat format = ExportFormat.markdown}) {
    if (format == ExportFormat.markdown) {
      return _exportMarkdown(messages);
    }
    return _exportPlainText(messages);
  }

  static String _exportMarkdown(List<ChatMessage> messages) {
    final buffer = StringBuffer();
    for (final msg in messages) {
      final role = msg.role == ChatRole.user ? 'User' : 'Assistant';
      buffer.writeln('## $role\n');

      if (msg.thinkingContent.isNotEmpty) {
        buffer.writeln('> *Thinking:*\n');
        buffer.writeln('> ${msg.thinkingContent.replaceAll('\n', '\n> ')}\n');
      }

      if (msg.content.isNotEmpty) {
        buffer.writeln('${msg.content}\n');
      }

      for (final toolResult in msg.toolResults) {
        buffer.writeln('**${toolResult.tool}**: ${toolResult.description}\n');
        if (toolResult.content != null) {
          buffer.writeln('```\n${toolResult.content!.summary}\n```\n');
        }
      }

      buffer.writeln('---\n');
    }
    return buffer.toString().trim();
  }

  static String _exportPlainText(List<ChatMessage> messages) {
    final buffer = StringBuffer();
    for (final msg in messages) {
      final role = msg.role == ChatRole.user ? 'User' : 'Assistant';
      buffer.writeln('--- $role ---');

      if (msg.thinkingContent.isNotEmpty) {
        buffer.writeln('[Thinking: ${msg.thinkingContent}]');
      }

      if (msg.content.isNotEmpty) {
        buffer.writeln(msg.content);
      }

      for (final toolResult in msg.toolResults) {
        buffer.writeln('[${toolResult.tool}: ${toolResult.description}]');
        if (toolResult.content != null) {
          buffer.writeln('[Content: ${toolResult.content!.summary}]');
        }
      }

      buffer.writeln();
    }
    return buffer.toString().trim();
  }
}
