import 'dart:async';
import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'package:samantha/features/chat/data/chat_socket_client.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:samantha/features/connection_settings/data/connection_settings_repository.dart';

@lazySingleton
class ChatRepository {
  final ChatSocketClient _socketClient;
  final ConnectionSettingsRepository _settingsRepository;

  ChatRepository(this._socketClient, this._settingsRepository);

  Stream<ChatEvent> get events => _socketClient.events;
  bool get isConnected => _socketClient.isConnected;

  Future<void> connect() async {
    final host = await _settingsRepository.getHost();
    final token = await _settingsRepository.getAuthToken();

    if (host == null || token == null) {
      throw Exception('Connection settings not configured');
    }

    await _socketClient.connect(host, token);
  }

  void send(String prompt, {String? model, List<PendingAttachment> attachments = const []}) =>
      _socketClient.sendPrompt(prompt, model: model, attachments: attachments);

  void stop() => _socketClient.stop();

  void setModel(String model) => _socketClient.setModel(model);

  void requestModels() => _socketClient.requestModels();

  void requestSessionMessages(String sessionId) =>
      _socketClient.requestSessionMessages(sessionId);

  void respondToPermission(String id, String response) =>
      _socketClient.sendPermissionResponse(id, response);

  void setProject(String path) => _socketClient.setProject(path);

  void setSession(String sessionId, String path) =>
      _socketClient.setSession(sessionId, path);

  Future<String?> getProjectPath() => _settingsRepository.getProjectPath();

  Future<String?> getSessionId() => _settingsRepository.getSessionId();

  Future<String?> getSessionName() => _settingsRepository.getSessionName();

  Future<String?> getLastActivity() => _settingsRepository.getLastActivity();

  Future<void> disconnect() async {
    _socketClient.disconnect();
  }

  ToolContent? parseToolContent(String tool, String? rawContent) {
    if (rawContent == null || rawContent.isEmpty) return null;

    if (tool == 'todowrite') {
      try {
        final decoded = jsonDecode(rawContent);
        if (decoded is List) {
          final todos = decoded
              .whereType<Map<String, dynamic>>()
              .map((m) => TodoItem(
                    content: m['content'] as String? ?? '',
                    status: m['status'] as String? ?? 'pending',
                    priority: m['priority'] as String? ?? 'medium',
                  ))
              .toList();
          if (todos.isNotEmpty) return TodoToolContent(todos);
        }
      } catch (_) {}
    }

    return RawToolContent(rawContent);
  }
}
