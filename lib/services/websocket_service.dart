import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:samantha/models/settings.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  Future<void> connect(ConnectionSettings settings) async {
    final uri = Uri.parse(settings.wsUrl);
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (data) {
        try {
          final json = data as String;
              final parsed = jsonDecode(json) as Map<String, dynamic>;
          _messageController.add(parsed);
        } catch (_) {
          _messageController.add({'type': 'output', 'content': data as String});
        }
      },
      onError: (err) {
        _messageController.addError(err);
      },
      onDone: () {
        _messageController
            .add({'type': 'status', 'status': 'disconnected'});
      },
    );
  }

  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
