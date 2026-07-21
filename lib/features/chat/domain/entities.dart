class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final String thinkingContent;

  /// Time the model spent reasoning, summed across the turn's reasoning blocks.
  /// Distinct from [duration], which covers the whole turn including tool calls.
  final Duration? thinkingDuration;
  final bool isStreaming;
  final List<ToolResult> toolResults;
  final Duration? duration;
  final int? inputTokens;
  final int? outputTokens;
  final double? cost;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    this.content = '',
    this.thinkingContent = '',
    this.thinkingDuration,
    this.isStreaming = false,
    this.toolResults = const [],
    this.duration,
    this.inputTokens,
    this.outputTokens,
    this.cost,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    String? thinkingContent,
    Duration? thinkingDuration,
    bool? isStreaming,
    List<ToolResult>? toolResults,
    Duration? duration,
    int? inputTokens,
    int? outputTokens,
    double? cost,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      thinkingContent: thinkingContent ?? this.thinkingContent,
      thinkingDuration: thinkingDuration ?? this.thinkingDuration,
      isStreaming: isStreaming ?? this.isStreaming,
      toolResults: toolResults ?? this.toolResults,
      duration: duration ?? this.duration,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      cost: cost ?? this.cost,
      timestamp: timestamp ?? this.timestamp,
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

extension ToolContentSummary on ToolContent {
  String get summary {
    return switch (this) {
      RawToolContent(content: final c) => _textSummary(c),
      TodoToolContent(todos: final todos) => '${todos.length} todo${todos.length == 1 ? '' : 's'}',
    };
  }

  String _textSummary(String text) {
    if (text.isEmpty) return 'empty';
    final lines = text.split('\n').length;
    final bytes = text.length;
    if (bytes < 1024) return '$lines line${lines == 1 ? '' : 's'}';
    final kb = bytes / 1024;
    if (kb < 10) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}

enum ChatRole { user, assistant }
