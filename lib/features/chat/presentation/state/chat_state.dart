import 'package:samantha/features/chat/domain/entities.dart';

enum ChatConnectionStatus { disconnected, connecting, connected, streaming }

class ChatState {
  final List<ChatMessage> messages;
  final ChatConnectionStatus connectionStatus;
  final String? errorMessage;
  final String inputText;
  final List<ModelProvider> availableModels;
  final String? selectedModel;

  const ChatState({
    this.messages = const [],
    this.connectionStatus = ChatConnectionStatus.disconnected,
    this.errorMessage,
    this.inputText = '',
    this.availableModels = const [],
    this.selectedModel,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    ChatConnectionStatus? connectionStatus,
    String? errorMessage,
    bool clearError = false,
    String? inputText,
    List<ModelProvider>? availableModels,
    String? selectedModel,
    bool clearSelectedModel = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      inputText: inputText ?? this.inputText,
      availableModels: availableModels ?? this.availableModels,
      selectedModel: clearSelectedModel ? null : (selectedModel ?? this.selectedModel),
    );
  }
}

class ModelProvider {
  final String id;
  final String name;
  final List<ModelInfo> models;

  const ModelProvider({
    required this.id,
    required this.name,
    this.models = const [],
  });

  factory ModelProvider.fromJson(Map<String, dynamic> json) {
    final providerId = json['id'] as String;
    return ModelProvider(
      id: providerId,
      name: json['name'] as String? ?? providerId,
      models: (json['models'] as List?)
              ?.map((m) => ModelInfo.fromJson(
                    m as Map<String, dynamic>,
                    providerId: providerId,
                  ))
              .toList() ??
          [],
    );
  }
}

class ModelInfo {
  final String id;
  final String name;
  final String providerId;

  const ModelInfo({
    required this.id,
    required this.providerId,
    this.name = '',
  });

  factory ModelInfo.fromJson(Map<String, dynamic> json,
      {required String providerId}) {
    return ModelInfo(
      id: json['id'] as String,
      providerId: providerId,
      name: json['name'] as String? ?? json['id'] as String,
    );
  }

  String get qualifiedId => '$providerId/$id';
  String get displayName => name.isEmpty ? id : name;
}
