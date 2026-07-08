import 'dart:async';
import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

sealed class ChatEvent {}

class TokenEvent extends ChatEvent {
  final String content;
  TokenEvent(this.content);
}

class DoneEvent extends ChatEvent {}

class ErrorEvent extends ChatEvent {
  final String message;
  ErrorEvent(this.message);
}

class AuthFailedEvent extends ChatEvent {
  final String message;
  AuthFailedEvent(this.message);
}

class ModelsEvent extends ChatEvent {
  final List<Map<String, dynamic>> providers;
  ModelsEvent(this.providers);
}

class ModelSetEvent extends ChatEvent {
  final String model;
  ModelSetEvent(this.model);
}

@injectable
class ChatSocketClient {
  WebSocketChannel? _channel;
  final _eventController = StreamController<ChatEvent>.broadcast();

  Stream<ChatEvent> get events => _eventController.stream;
  bool get isConnected => _channel != null;

  Future<void> connect(String host, String authToken) async {
    disconnect();

    final uri = Uri.parse('ws://$host:8383/chat');
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;

    // Wait for the WebSocket handshake to actually complete. `ready`
    // throws if the TCP/TLS connection or the HTTP upgrade fails, so the
    // caller sees a real error instead of a false "connected".
    try {
      await channel.ready;
    } catch (e) {
      _channel = null;
      throw Exception('WebSocket connection failed: $e');
    }

    channel.sink.add(jsonEncode({'type': 'auth', 'token': authToken}));

    channel.stream.listen(
      (data) {
        try {
          final parsed = jsonDecode(data) as Map<String, dynamic>;
          switch (parsed['type']) {
            case 'token':
              _eventController.add(TokenEvent(parsed['content'] ?? ''));
            case 'done':
              _eventController.add(DoneEvent());
            case 'auth_failed':
              _channel = null;
              _eventController
                  .add(AuthFailedEvent(parsed['message'] ?? 'Authentication failed'));
            case 'error':
              final message = parsed['message'] ?? 'Unknown error';
              if (message == 'Authentication failed') {
                _channel = null;
                _eventController.add(AuthFailedEvent(message));
              } else {
                _eventController.add(ErrorEvent(message));
              }
            case 'models':
              final providers = (parsed['providers'] as List)
                  .cast<Map<String, dynamic>>();
              _eventController.add(ModelsEvent(providers));
            case 'model_set':
              _eventController.add(ModelSetEvent(parsed['model'] ?? ''));
          }
        } catch (_) {}
      },
      onError: (err) {
        _eventController.add(ErrorEvent(err.toString()));
      },
      onDone: () {
        _channel = null;
      },
    );
  }

  void sendPrompt(String content, {String? model}) {
    if (_channel != null) {
      final msg = <String, dynamic>{'type': 'prompt', 'content': content};
      if (model != null) msg['model'] = model;
      _channel!.sink.add(jsonEncode(msg));
    }
  }

  void setModel(String model) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({'type': 'set_model', 'model': model}));
    }
  }

  void requestModels() {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({'type': 'get_models'}));
    }
  }

  void setProject(String path) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({'type': 'set_project', 'path': path}));
    }
  }

  void setSession(String sessionId, String path) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'set_session',
        'session_id': sessionId,
        'path': path,
      }));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}