import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:samantha/features/chat/data/chat_socket_client.dart';
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

  void send(String prompt) => _socketClient.sendPrompt('$prompt\n');

  Future<void> disconnect() async {
    _socketClient.disconnect();
  }
}
