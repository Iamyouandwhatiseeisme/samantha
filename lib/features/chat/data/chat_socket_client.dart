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
            case 'status':
              break;
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

  void sendPrompt(String content) {
    if (_channel != null) {
      _channel!.sink
          .add(jsonEncode({'type': 'prompt', 'content': content}));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}