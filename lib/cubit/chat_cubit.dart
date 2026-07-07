import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/cubit/chat_state.dart';
import 'package:samantha/models/message.dart';
import 'package:samantha/models/settings.dart';
import 'package:samantha/services/websocket_service.dart';

export 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  final WebSocketService _wsService;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  ChatCubit(this._wsService) : super(const ChatState());

  void updateInput(String text) {
    emit(state.copyWith(inputText: text));
  }

  void sendMessage() {
    final text = state.inputText.trim();
    if (text.isEmpty) return;

    final message = Message(content: text, isUser: true);
    emit(state.copyWith(
      messages: [...state.messages, message],
      inputText: '',
    ));

    _wsService.send({'type': 'input', 'content': '$text\n'});
  }

  Future<void> connect(ConnectionSettings settings) async {
    emit(state.copyWith(
      connectionStatus: ConnectionStatus.connecting,
      clearError: true,
    ));

    _subscription = _wsService.messages.listen(
      (msg) {
        switch (msg['type']) {
          case 'output':
            _addMessage(msg['content'] as String, isUser: false);
          case 'status':
            final status = msg['status'] as String?;
            if (status == 'connected') {
              emit(state.copyWith(
                  connectionStatus: ConnectionStatus.connected));
            } else if (status == 'error' || status == 'stopped') {
              emit(state.copyWith(
                errorMessage: msg['message'] as String?,
                connectionStatus: ConnectionStatus.disconnected,
              ));
            }
        }
      },
      onError: (err) {
        emit(state.copyWith(
          errorMessage: err.toString(),
          connectionStatus: ConnectionStatus.disconnected,
        ));
      },
    );

    await _wsService.connect(settings);
    emit(state.copyWith(connectionStatus: ConnectionStatus.connected));
  }

  void disconnect() {
    _subscription?.cancel();
    _wsService.disconnect();
    emit(state.copyWith(connectionStatus: ConnectionStatus.disconnected));
  }

  void _addMessage(String content, {required bool isUser}) {
    final message = Message(content: content, isUser: isUser);
    emit(state.copyWith(messages: [...state.messages, message]));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    _wsService.disconnect();
    return super.close();
  }
}
