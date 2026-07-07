import 'package:samantha/features/chat/domain/entities.dart';

enum ChatConnectionStatus { disconnected, connecting, connected, streaming }

class ChatState {
  final List<ChatMessage> messages;
  final ChatConnectionStatus connectionStatus;
  final String? errorMessage;
  final String inputText;

  const ChatState({
    this.messages = const [],
    this.connectionStatus = ChatConnectionStatus.disconnected,
    this.errorMessage,
    this.inputText = '',
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    ChatConnectionStatus? connectionStatus,
    String? errorMessage,
    bool clearError = false,
    String? inputText,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      inputText: inputText ?? this.inputText,
    );
  }
}
