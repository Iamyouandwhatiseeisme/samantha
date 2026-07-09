import 'dart:convert';

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final String thinkingContent;
  final bool isStreaming;
  final List<ToolResult> toolResults;

  ChatMessage({
    required this.id,
    required this.role,
    this.content = '',
    this.thinkingContent = '',
    this.isStreaming = false,
    this.toolResults = const [],
  });

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    String? thinkingContent,
    bool? isStreaming,
    List<ToolResult>? toolResults,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      thinkingContent: thinkingContent ?? this.thinkingContent,
      isStreaming: isStreaming ?? this.isStreaming,
      toolResults: toolResults ?? this.toolResults,
    );
  }
}

class ToolResult {
  final String tool;
  final String description;
  final String? content;
  const ToolResult({
    required this.tool,
    required this.description,
    this.content,
  });

  List<TodoItem> get parsedTodos {
    if (tool != 'todowrite' || content == null || content!.isEmpty) return [];
    try {
      final decoded = jsonDecode(content!);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((m) => TodoItem(
                  content: m['content'] as String? ?? '',
                  status: m['status'] as String? ?? 'pending',
                  priority: m['priority'] as String? ?? 'medium',
                ))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}

class TodoItem {
  final String content;
  final String status;
  final String priority;
  const TodoItem({
    required this.content,
    required this.status,
    this.priority = 'medium',
  });
}

enum ChatRole { user, assistant }
