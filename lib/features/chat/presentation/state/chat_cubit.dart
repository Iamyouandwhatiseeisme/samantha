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
  bool _userSelectedModel = false;

  ChatCubit(this._repository) : super(const ChatState());

  void updateInput(String text) {
    emit(state.copyWith(inputText: text));
  }

  void sendMessage() {
    final text = state.inputText.trim();
    if (text.isEmpty && state.attachments.isEmpty) return;

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final userMessage = ChatMessage(
      id: messageId,
      role: ChatRole.user,
      content: text,
    );

    emit(state.copyWith(
      messages: [
        ...state.messages,
        userMessage,
        ChatMessage(
          id: '${messageId}_ai',
          role: ChatRole.assistant,
          isStreaming: true,
        ),
      ],
      inputText: '',
      clearToolName: true,
      clearToolStatus: true,
      clearPermissionId: true,
      clearPermissionTitle: true,
      clearAttachments: true,
    ));

    _repository.send(text, model: state.selectedModel, attachments: state.attachments);
  }

  void addAttachment(PendingAttachment attachment) {
    emit(state.copyWith(
      attachments: [...state.attachments, attachment],
    ));
  }

  void removeAttachment(int index) {
    if (index < 0 || index >= state.attachments.length) return;
    final updated = List<PendingAttachment>.from(state.attachments);
    updated.removeAt(index);
    emit(state.copyWith(attachments: updated));
  }

  void clearAttachments() {
    emit(state.copyWith(clearAttachments: true));
  }

  void stopGeneration() {
    _repository.stop();

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
      clearToolName: true,
      clearToolStatus: true,
    ));
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
          currentProjectPath: projectPath,
          sessionName: await _repository.getSessionName(),
          lastActivity: await _repository.getLastActivity()));
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
          case DoneEvent(durationMs: final durationMs, inputTokens: final input, outputTokens: final output, cost: final cost):
            _handleDone(durationMs, input, output, cost);
          case ErrorEvent(:final message):
            emit(state.copyWith(errorMessage: message));
          case AuthFailedEvent(:final message):
            _handleAuthFailed(message);
          case ModelsEvent(:final providers):
            _handleModels(providers);
          case ModelSetEvent(:final model):
            emit(state.copyWith(selectedModel: model));
          case CurrentModelEvent(:final model):
            if (!_userSelectedModel) {
              emit(state.copyWith(selectedModel: model));
            }
          case SessionMessagesEvent(:final messages):
            _handleSessionMessages(messages);
          case ThinkingEvent(:final content):
            _handleThinking(content);
          case ThinkingEndEvent(:final durationMs):
            _handleThinkingEnd(durationMs);
          case ToolEvent(:final tool, :final status, :final title, :final description, :final content):
            _handleTool(tool, status, title ?? description, content: content);
          case PermissionRequestEvent(:final id, :final title):
            _handlePermission(id, title);
          case ImageEvent(:final url, :final mimeType, :final filename):
            _handleImage(url, mimeType, filename);
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

  /// Pops the in-progress assistant message off [messages] so the caller can
  /// amend it, creating a fresh one when the turn has not started yet.
  ChatMessage _takeStreamingMessage(List<ChatMessage> messages) {
    if (messages.isNotEmpty &&
        messages.last.role == ChatRole.assistant &&
        messages.last.isStreaming) {
      return messages.removeLast();
    }
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: ChatRole.assistant,
      isStreaming: true,
    );
  }

  void _handleToken(String content) {
    final messages = List<ChatMessage>.from(state.messages);
    final streamingMessage = _takeStreamingMessage(messages);

    messages.add(streamingMessage.copyWith(
      content: streamingMessage.content + content,
    ));

    emit(state.copyWith(
      messages: messages,
      connectionStatus: ChatConnectionStatus.streaming,
    ));
  }

  void _handleThinking(String content) {
    final messages = List<ChatMessage>.from(state.messages);
    final streamingMessage = _takeStreamingMessage(messages);

    messages.add(streamingMessage.copyWith(
      thinkingContent: streamingMessage.thinkingContent + content,
    ));

    emit(state.copyWith(
      messages: messages,
      connectionStatus: ChatConnectionStatus.streaming,
    ));
  }

  /// A reasoning block closed. A turn can contain several — one per agent step —
  /// so separate them and accumulate their elapsed time.
  void _handleThinkingEnd(int? durationMs) {
    final messages = List<ChatMessage>.from(state.messages);
    final streamingMessage = _takeStreamingMessage(messages);

    final elapsed = durationMs != null ? Duration(milliseconds: durationMs) : null;
    final total = elapsed == null
        ? streamingMessage.thinkingDuration
        : (streamingMessage.thinkingDuration ?? Duration.zero) + elapsed;

    messages.add(streamingMessage.copyWith(
      thinkingContent: streamingMessage.thinkingContent.isEmpty
          ? streamingMessage.thinkingContent
          : '${streamingMessage.thinkingContent}\n\n',
      thinkingDuration: total,
    ));

    emit(state.copyWith(
      messages: messages,
      connectionStatus: ChatConnectionStatus.streaming,
    ));
  }

  void _handleDone(int? durationMs, int? inputTokens, int? outputTokens, double? cost) {
    final duration = durationMs != null ? Duration(milliseconds: durationMs) : null;

    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isNotEmpty &&
        messages.last.role == ChatRole.assistant &&
        messages.last.isStreaming) {
      final last = messages.removeLast();
      messages.add(last.copyWith(
        isStreaming: false,
        duration: duration,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        cost: cost,
      ));
    }

    emit(state.copyWith(
      messages: messages,
      connectionStatus: ChatConnectionStatus.connected,
      clearToolName: true,
      clearToolStatus: true,
      clearPermissionId: true,
      clearPermissionTitle: true,
    ));

    _reconnectAttempt = 0;
  }

  void _handleTool(String tool, String status, String description, {String? content}) {
    if (status == 'completed' || status == 'error') {
      final parsedContent = _repository.parseToolContent(tool, content);
      final messages = List<ChatMessage>.from(state.messages);
      if (messages.isNotEmpty &&
          messages.last.role == ChatRole.assistant &&
          messages.last.isStreaming) {
        final last = messages.removeLast();
        messages.add(last.copyWith(
          toolResults: [
            ...last.toolResults,
            ToolResult(tool: tool, description: description, content: parsedContent),
          ],
        ));
      } else {
        messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: ChatRole.assistant,
          toolResults: [ToolResult(tool: tool, description: description, content: parsedContent)],
        ));
      }
      emit(state.copyWith(
        messages: messages,
        clearToolName: true,
        clearToolStatus: true,
      ));
    } else {
      emit(state.copyWith(
        connectionStatus: ChatConnectionStatus.streaming,
        currentToolName: tool,
        currentToolStatus: '$status: $description',
      ));
    }
  }

  void _handlePermission(String id, String title) {
    emit(state.copyWith(
      currentPermissionId: id,
      currentPermissionTitle: title,
    ));
  }

  void _handleImage(String url, String? mimeType, String? filename) {
    final messages = List<ChatMessage>.from(state.messages);
    final streamingMessage = _takeStreamingMessage(messages);

    messages.add(streamingMessage.copyWith(
      images: [...streamingMessage.images, ChatImage(url: url, mimeType: mimeType, filename: filename)],
    ));

    emit(state.copyWith(
      messages: messages,
      connectionStatus: ChatConnectionStatus.streaming,
    ));
  }

  void respondToPermission(bool allow) {
    final id = state.currentPermissionId;
    if (id == null) return;
    _repository.respondToPermission(id, allow ? 'allow' : 'deny');
    emit(state.copyWith(
      clearPermissionId: true,
      clearPermissionTitle: true,
    ));
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
      final thinkingContent = m['thinkingContent'] as String? ?? '';
      final thinkingMs = m['thinkingMs'] as int?;
      final thinkingDuration =
          thinkingMs != null ? Duration(milliseconds: thinkingMs) : null;

      final List<ToolResult> toolResults = [];
      final rawToolResults = m['toolResults'];
      if (rawToolResults is List) {
        for (final tr in rawToolResults) {
          if (tr is Map) {
            final tool = tr['tool'] as String? ?? '';
            final description = tr['description'] as String? ?? '';
            final rawContent = tr['content'] as String?;
            toolResults.add(ToolResult(
              tool: tool,
              description: description,
              content: _repository.parseToolContent(tool, rawContent),
            ));
          }
        }
      }

      final durationMs = m['duration'] as int?;
      final duration = durationMs != null ? Duration(milliseconds: durationMs) : null;

      final inputTokens = m['inputTokens'] as int?;
      final outputTokens = m['outputTokens'] as int?;
      final cost = (m['cost'] as num?)?.toDouble();

      final rawTs = m['timestamp'];
      DateTime? timestamp;
      if (rawTs is String) {
        timestamp = DateTime.tryParse(rawTs);
      } else if (rawTs is int) {
        timestamp = DateTime.fromMillisecondsSinceEpoch(rawTs);
      }

      final List<ChatImage> images = [];
      final rawImages = m['images'];
      if (rawImages is List) {
        for (final img in rawImages) {
          if (img is Map) {
            final url = img['url'] as String?;
            if (url != null && url.isNotEmpty) {
              images.add(ChatImage(
                url: url,
                mimeType: img['mime_type'] as String?,
                filename: img['filename'] as String?,
              ));
            }
          }
        }
      }

      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString() + content.hashCode.toString(),
        role: role,
        content: content,
        thinkingContent: thinkingContent,
        thinkingDuration: thinkingDuration,
        toolResults: toolResults,
        images: images,
        duration: duration,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        cost: cost,
        timestamp: timestamp,
      );
    }).toList();
    emit(state.copyWith(messages: chatMessages));
  }

  void setModel(String model) {
    _userSelectedModel = true;
    emit(state.copyWith(selectedModel: model));
    _repository.setModel(model);
  }

  void retryMessage(String messageId) {
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;

    final msg = state.messages[idx];
    if (msg.role == ChatRole.user && idx + 1 < state.messages.length) {
      final assistantMsg = state.messages[idx + 1];
      if (assistantMsg.role == ChatRole.assistant) {
        final newMessages = state.messages.sublist(0, idx + 1);
        newMessages.add(assistantMsg.copyWith(
          content: '',
          thinkingContent: '',
          thinkingDuration: null,
          toolResults: [],
          isStreaming: true,
          duration: null,
          inputTokens: null,
          outputTokens: null,
          cost: null,
        ));

        emit(state.copyWith(
          messages: newMessages,
          connectionStatus: ChatConnectionStatus.streaming,
          clearToolName: true,
          clearToolStatus: true,
        ));

        _repository.send(msg.content, model: state.selectedModel);
      }
    } else if (msg.role == ChatRole.assistant && !msg.isStreaming) {
      final userIdx = idx - 1;
      if (userIdx >= 0 && state.messages[userIdx].role == ChatRole.user) {
        final userMsg = state.messages[userIdx];
        final newMessages = state.messages.sublist(0, idx);
        newMessages.add(msg.copyWith(
          content: '',
          thinkingContent: '',
          thinkingDuration: null,
          toolResults: [],
          isStreaming: true,
          duration: null,
          inputTokens: null,
          outputTokens: null,
          cost: null,
        ));

        emit(state.copyWith(
          messages: newMessages,
          connectionStatus: ChatConnectionStatus.streaming,
          clearToolName: true,
          clearToolStatus: true,
        ));

        _repository.send(userMsg.content, model: state.selectedModel);
      }
    }
  }

  void editMessage(String messageId, String newContent) {
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx == -1 || newContent.trim().isEmpty) return;

    final newMessages = state.messages.sublist(0, idx);
    final editedUser = state.messages[idx].copyWith(content: newContent.trim());
    newMessages.add(editedUser);
    newMessages.add(ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_ai',
      role: ChatRole.assistant,
      isStreaming: true,
    ));

    emit(state.copyWith(
      messages: newMessages,
      inputText: '',
      connectionStatus: ChatConnectionStatus.streaming,
      clearToolName: true,
      clearToolStatus: true,
      clearPermissionId: true,
      clearPermissionTitle: true,
    ));

    _repository.send(newContent.trim(), model: state.selectedModel);
  }

  void branchFromMessage(String messageId) {
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;

    final isUserMessage = state.messages[idx].role == ChatRole.user;
    final cutIndex = isUserMessage ? idx + 1 : idx;

    final newMessages = state.messages.sublist(0, cutIndex);

    if (!isUserMessage && newMessages.isNotEmpty && newMessages.last.role == ChatRole.user) {
      final lastUser = newMessages.last;
      newMessages.add(ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_ai',
        role: ChatRole.assistant,
        isStreaming: true,
      ));

      emit(state.copyWith(
        messages: newMessages,
        connectionStatus: ChatConnectionStatus.streaming,
        clearToolName: true,
        clearToolStatus: true,
      ));

      _repository.send(lastUser.content, model: state.selectedModel);
    } else if (isUserMessage && cutIndex < state.messages.length) {
      final assistantMsg = state.messages[cutIndex];
      newMessages.add(assistantMsg.copyWith(
        content: '',
        thinkingContent: '',
        thinkingDuration: null,
        toolResults: [],
        isStreaming: true,
        duration: null,
        inputTokens: null,
        outputTokens: null,
        cost: null,
      ));

      emit(state.copyWith(
        messages: newMessages,
        connectionStatus: ChatConnectionStatus.streaming,
        clearToolName: true,
        clearToolStatus: true,
      ));

      final userMsg = state.messages[idx];
      _repository.send(userMsg.content, model: state.selectedModel);
    }
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
