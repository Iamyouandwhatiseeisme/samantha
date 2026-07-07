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

@injectable
class ChatSocketClient {
  WebSocketChannel? _channel;
  final _eventController = StreamController<ChatEvent>.broadcast();

  Stream<ChatEvent> get events => _eventController.stream;
  bool get isConnected => _channel != null;

  Future<void> connect(String host, String authToken) async {
    disconnect();

    final uri = Uri.parse('ws://$host:8383/chat');
    _channel = WebSocketChannel.connect(uri);

    _channel!.sink.add(jsonEncode({'type': 'auth', 'token': authToken}));

    _channel!.stream.listen(
      (data) {
        try {
          final parsed = jsonDecode(data) as Map<String, dynamic>;
          switch (parsed['type']) {
            case 'token':
              _eventController.add(TokenEvent(parsed['content']));
            case 'done':
              _eventController.add(DoneEvent());
            case 'error':
              _eventController.add(ErrorEvent(parsed['message']));
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
