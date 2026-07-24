import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:samantha/features/chat/domain/entities.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

sealed class ChatEvent {}

class TokenEvent extends ChatEvent {
  final String content;
  TokenEvent(this.content);
}

class DoneEvent extends ChatEvent {
  final int? durationMs;
  final int? inputTokens;
  final int? outputTokens;
  final double? cost;
  DoneEvent({this.durationMs, this.inputTokens, this.outputTokens, this.cost});
}

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

/// The active session's chosen model, fetched by the bridge from opencode serve.
/// Distinct from ModelSetEvent (which acknowledges an explicit set_model) so the
/// cubit can avoid clobbering a user's manual pick on reconnect.
class CurrentModelEvent extends ChatEvent {
  final String model;
  CurrentModelEvent(this.model);
}

class SessionMessagesEvent extends ChatEvent {
  final List<Map<String, dynamic>> messages;
  SessionMessagesEvent(this.messages);
}

class ThinkingEvent extends ChatEvent {
  final String content;
  ThinkingEvent(this.content);
}

/// A reasoning block finished. [durationMs] is the block's own elapsed time,
/// not the turn's.
class ThinkingEndEvent extends ChatEvent {
  final int? durationMs;
  ThinkingEndEvent(this.durationMs);
}

class ToolEvent extends ChatEvent {
  final String tool;
  final String status;
  final String description;
  final String? output;
  final String? error;
  final String? title;
  final String? callID;
  final String? content;
  ToolEvent({
    required this.tool,
    required this.status,
    this.description = '',
    this.output,
    this.error,
    this.title,
    this.callID,
    this.content,
  });
}

class PermissionRequestEvent extends ChatEvent {
  final String id;
  final String title;
  PermissionRequestEvent({required this.id, this.title = ''});
}

class ImageEvent extends ChatEvent {
  final String url;
  final String? mimeType;
  final String? filename;
  ImageEvent({required this.url, this.mimeType, this.filename});
}

class TurnStatusEvent extends ChatEvent {
  final String? sessionId;
  final bool isActive;
  final String lastMessageContent;
  TurnStatusEvent({
    this.sessionId,
    required this.isActive,
    this.lastMessageContent = '',
  });
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

    // Request current model after auth
    channel.sink.add(jsonEncode({'type': 'get_models'}));

    channel.stream.listen(
      (data) {
        try {
          final parsed = jsonDecode(data) as Map<String, dynamic>;
          switch (parsed['type']) {
            case 'token':
              _eventController.add(TokenEvent(parsed['content'] ?? ''));
            case 'done':
              _eventController.add(DoneEvent(
                durationMs: parsed['duration_ms'] as int?,
                inputTokens: parsed['input_tokens'] as int?,
                outputTokens: parsed['output_tokens'] as int?,
                cost: (parsed['cost'] as num?)?.toDouble(),
              ));
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
              final model = parsed['model'] ?? '';
              debugPrint('[Bridge] Current model set: $model');
              _eventController.add(ModelSetEvent(model));
            case 'current_model':
              final model = parsed['model'] ?? '';
              debugPrint('[Bridge] Current model from opencode: $model');
              _eventController.add(CurrentModelEvent(model));
            case 'session_messages':
              final msgs = (parsed['messages'] as List)
                  .cast<Map<String, dynamic>>();
              _eventController.add(SessionMessagesEvent(msgs));
            case 'thinking':
              _eventController.add(ThinkingEvent(parsed['content'] ?? ''));
            case 'thinking_end':
              _eventController.add(ThinkingEndEvent(parsed['duration_ms'] as int?));
            case 'tool':
              _eventController.add(ToolEvent(
                tool: parsed['tool'] ?? '',
                status: parsed['status'] ?? 'pending',
              description: parsed['description'] ?? '',
                output: parsed['output'],
                error: parsed['error'],
                title: parsed['title'],
                callID: parsed['callID'],
                content: parsed['content'],
              ));
          case 'permission_request':
            _eventController.add(PermissionRequestEvent(
              id: parsed['id'] ?? '',
              title: parsed['title'] ?? '',
            ));
          case 'image':
            _eventController.add(ImageEvent(
              url: parsed['url'] ?? '',
              mimeType: parsed['mime_type'],
              filename: parsed['filename'],
            ));
          case 'turn_status':
            _eventController.add(TurnStatusEvent(
              sessionId: parsed['session_id'],
              isActive: parsed['is_active'] == true,
              lastMessageContent: parsed['last_message_content'] ?? '',
            ));
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

  void sendPrompt(String content, {String? model, List<PendingAttachment> attachments = const []}) {
    if (_channel != null) {
      final msg = <String, dynamic>{'type': 'prompt', 'content': content};
      if (model != null) {
        msg['model'] = model;
        debugPrint('[Bridge] Sending prompt with model: $model');
      }
      if (attachments.isNotEmpty) {
        msg['attachments'] = attachments.map((a) => {
          'name': a.name,
          'mime_type': a.mimeType,
          'data': a.base64Data,
          'size': a.sizeBytes,
        }).toList();
        debugPrint('[Bridge] Sending prompt with ${attachments.length} attachment(s)');
      }
      _channel!.sink.add(jsonEncode(msg));
    }
  }

  void stop() {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({'type': 'stop'}));
    }
  }

  void sendPermissionResponse(String id, String response) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'permission_response',
        'id': id,
        'response': response,
      }));
    }
  }

  void setModel(String model) {
    debugPrint('[Bridge] Setting model: $model');
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({'type': 'set_model', 'model': model}));
    } else {
      debugPrint('[Bridge] Cannot set model: not connected');
    }
  }

  void requestModels() {
    debugPrint('[Bridge] Requesting available models');
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({'type': 'get_models'}));
    }
  }

  void requestSessionMessages(String sessionId) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'get_session_messages',
        'session_id': sessionId,
      }));
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

  void requestTurnStatus() {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({'type': 'turn_status'}));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}