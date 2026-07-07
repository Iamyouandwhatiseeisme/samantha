import 'package:samantha/models/message.dart';

enum ConnectionStatus { disconnected, connecting, connected }

class ChatState {
  final List<Message> messages;
  final ConnectionStatus connectionStatus;
  final String? errorMessage;
  final String inputText;

  const ChatState({
    this.messages = const [],
    this.connectionStatus = ConnectionStatus.disconnected,
    this.errorMessage,
    this.inputText = '',
  });

  ChatState copyWith({
    List<Message>? messages,
    ConnectionStatus? connectionStatus,
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
