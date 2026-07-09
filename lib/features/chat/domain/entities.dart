class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final String thinkingContent;
  final bool isStreaming;
  final List<ToolResult> toolResults;
  final Duration? duration;

  ChatMessage({
    required this.id,
    required this.role,
    this.content = '',
    this.thinkingContent = '',
    this.isStreaming = false,
    this.toolResults = const [],
    this.duration,
  });

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    String? thinkingContent,
    bool? isStreaming,
    List<ToolResult>? toolResults,
    Duration? duration,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      thinkingContent: thinkingContent ?? this.thinkingContent,
      isStreaming: isStreaming ?? this.isStreaming,
      toolResults: toolResults ?? this.toolResults,
      duration: duration ?? this.duration,
    );
  }
}

sealed class ToolContent {
  const ToolContent();
}

class RawToolContent extends ToolContent {
  final String content;
  const RawToolContent(this.content);
}

class TodoToolContent extends ToolContent {
  final List<TodoItem> todos;
  const TodoToolContent(this.todos);
}

class ToolResult {
  final String tool;
  final String description;
  final ToolContent? content;
  const ToolResult({
    required this.tool,
    required this.description,
    this.content,
  });
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
