class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final String thinkingContent;
  final bool isStreaming;

  ChatMessage({
    required this.id,
    required this.role,
    this.content = '',
    this.thinkingContent = '',
    this.isStreaming = false,
  });

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    String? thinkingContent,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      thinkingContent: thinkingContent ?? this.thinkingContent,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

enum ChatRole { user, assistant }
