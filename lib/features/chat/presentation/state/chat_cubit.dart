import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:samantha/features/chat/data/chat_repository.dart';
import 'package:samantha/features/chat/data/chat_socket_client.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:samantha/features/chat/presentation/state/chat_state.dart';

@injectable
class ChatCubit extends Cubit<ChatState> {
  final ChatRepository _repository;
  StreamSubscription<ChatEvent>? _eventSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _authFailed = false;

  ChatCubit(this._repository) : super(const ChatState());

  void updateInput(String text) {
    emit(state.copyWith(inputText: text));
  }

  void sendMessage() {
    final text = state.inputText.trim();
    if (text.isEmpty) return;

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final userMessage = ChatMessage(
      id: messageId,
      role: ChatRole.user,
      content: text,
    );

    emit(state.copyWith(
      messages: [...state.messages, userMessage],
      inputText: '',
    ));

    _repository.send(text, model: state.selectedModel);
  }

  Future<void> connect() async {
    _reconnectTimer?.cancel();
    _authFailed = false;
    emit(state.copyWith(
      connectionStatus: ChatConnectionStatus.connecting,
      clearError: true,
    ));

    try {
      await _repository.connect();
      final sessionId = await _repository.getSessionId();
      final projectPath = await _repository.getProjectPath();
      if (sessionId != null && projectPath != null) {
        _repository.setSession(sessionId, projectPath);
      } else if (projectPath != null) {
        _repository.setProject(projectPath);
      }
      emit(state.copyWith(
          connectionStatus: ChatConnectionStatus.connected,
          currentProjectPath: projectPath));
      _setupEventListeners();
    } catch (e) {
      emit(state.copyWith(
        connectionStatus: ChatConnectionStatus.disconnected,
        errorMessage: e.toString(),
      ));
    }
  }

  void _setupEventListeners() {
    _eventSubscription?.cancel();

    _eventSubscription = _repository.events.listen(
      (event) {
        switch (event) {
          case TokenEvent(:final content):
            _handleToken(content);
          case DoneEvent():
            _handleDone();
          case ErrorEvent(:final message):
            emit(state.copyWith(errorMessage: message));
          case AuthFailedEvent(:final message):
            _handleAuthFailed(message);
          case ModelsEvent(:final providers):
            _handleModels(providers);
          case ModelSetEvent(:final model):
            emit(state.copyWith(selectedModel: model));
          case SessionMessagesEvent(:final messages):
            _handleSessionMessages(messages);
        }
      },
      onError: (err) {
        emit(state.copyWith(
          connectionStatus: ChatConnectionStatus.disconnected,
          errorMessage: err.toString(),
        ));
        if (!_authFailed) _attemptReconnect();
      },
      onDone: () {
        if (state.connectionStatus != ChatConnectionStatus.disconnected) {
          emit(state.copyWith(
            connectionStatus: ChatConnectionStatus.disconnected,
          ));
          if (!_authFailed) _attemptReconnect();
        }
      },
    );
  }

  void _handleToken(String content) {
    final messages = List<ChatMessage>.from(state.messages);

    final streamingMessage = messages.isNotEmpty &&
            messages.last.role == ChatRole.assistant &&
            messages.last.isStreaming
        ? messages.removeLast()
        : ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            role: ChatRole.assistant,
            isStreaming: true,
          );

    messages.add(streamingMessage.copyWith(
      content: streamingMessage.content + content,
    ));

    emit(state.copyWith(
      messages: messages,
      connectionStatus: ChatConnectionStatus.streaming,
    ));
  }

  void _handleDone() {
    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isNotEmpty &&
        messages.last.role == ChatRole.assistant &&
        messages.last.isStreaming) {
      final last = messages.removeLast();
      messages.add(last.copyWith(isStreaming: false));
    }

    emit(state.copyWith(
      messages: messages,
      connectionStatus: ChatConnectionStatus.connected,
    ));

    _reconnectAttempt = 0;
  }

  void _attemptReconnect() {
    _reconnectTimer?.cancel();
    const maxDelay = Duration(seconds: 30);
    final delay = Duration(
      seconds: min(pow(2, _reconnectAttempt).toInt(), maxDelay.inSeconds),
    );

    _reconnectTimer = Timer(delay, () {
      _reconnectAttempt++;
      connect();
    });
  }

  void _handleAuthFailed(String message) {
    _authFailed = true;
    _reconnectTimer?.cancel();
    emit(state.copyWith(
      connectionStatus: ChatConnectionStatus.disconnected,
      errorMessage: message,
    ));
  }

  void _handleModels(List<Map<String, dynamic>> providers) {
    final models = providers
        .map((p) => ModelProvider.fromJson(p))
        .toList();
    emit(state.copyWith(availableModels: models));
  }

  void _handleSessionMessages(List<Map<String, dynamic>> messages) {
    final chatMessages = messages.map((m) {
      final role = m['role'] == 'user' ? ChatRole.user : ChatRole.assistant;
      final content = m['content'] as String? ?? '';
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString() + content.hashCode.toString(),
        role: role,
        content: content,
      );
    }).toList();
    emit(state.copyWith(messages: chatMessages));
  }

  void setModel(String model) {
    emit(state.copyWith(selectedModel: model));
    _repository.setModel(model);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _eventSubscription?.cancel();
    _repository.disconnect();
    emit(state.copyWith(connectionStatus: ChatConnectionStatus.disconnected));
  }

  @override
  Future<void> close() {
    _reconnectTimer?.cancel();
    _eventSubscription?.cancel();
    _repository.disconnect();
    return super.close();
  }
}
