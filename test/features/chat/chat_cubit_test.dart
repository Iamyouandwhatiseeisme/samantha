import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samantha/features/chat/data/chat_repository.dart';
import 'package:samantha/features/chat/data/chat_socket_client.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/chat/presentation/state/chat_state.dart';
import 'package:samantha/features/notification/service/notification_service.dart';

class MockChatRepository extends Mock implements ChatRepository {}
class MockNotificationService extends Mock implements NotificationService {}

void main() {
  late MockChatRepository repository;
  late MockNotificationService notificationService;
  late StreamController<ChatEvent> eventController;

  setUp(() {
    registerFallbackValue(TokenEvent(''));
    registerFallbackValue(DoneEvent());
    registerFallbackValue(ErrorEvent(''));
    registerFallbackValue(AuthFailedEvent(''));

    repository = MockChatRepository();
    notificationService = MockNotificationService();
    eventController = StreamController<ChatEvent>.broadcast();

    when(() => repository.events).thenAnswer((_) => eventController.stream);
    when(() => repository.disconnect()).thenAnswer((_) async {});
    when(() => repository.getProjectPath()).thenAnswer((_) async => null);
    when(() => repository.getSessionId()).thenAnswer((_) async => null);
    when(() => repository.getSessionName()).thenAnswer((_) async => null);
    when(() => repository.setProject(any())).thenReturn(null);
    when(() => repository.setSession(any(), any())).thenReturn(null);
    when(() => notificationService.shouldNotifyOnCompletion).thenReturn(false);
  });

  tearDown(() {
    eventController.close();
  });

  group('ChatCubit', () {
    blocTest<ChatCubit, ChatState>(
      'emits connecting then connected on successful connect()',
      setUp: () {
        when(() => repository.connect()).thenAnswer((_) async {});
        when(() => repository.isConnected).thenReturn(true);
      },
      build: () => ChatCubit(repository, notificationService),
      act: (cubit) => cubit.connect(),
      expect: () => [
        isA<ChatState>()
            .having((s) => s.connectionStatus, 'status',
                ChatConnectionStatus.connecting),
        isA<ChatState>()
            .having((s) => s.connectionStatus, 'status',
                ChatConnectionStatus.connected),
      ],
    );

    blocTest<ChatCubit, ChatState>(
      'emits connecting then disconnected with error on connect() failure',
      setUp: () {
        when(() => repository.connect())
            .thenThrow(Exception('Connection refused'));
      },
      build: () => ChatCubit(repository, notificationService),
      act: (cubit) => cubit.connect(),
      expect: () => [
        isA<ChatState>()
            .having((s) => s.connectionStatus, 'status',
                ChatConnectionStatus.connecting),
        isA<ChatState>()
            .having((s) => s.connectionStatus, 'status',
                ChatConnectionStatus.disconnected)
            .having((s) => s.errorMessage, 'error',
                contains('Connection refused')),
      ],
    );

    blocTest<ChatCubit, ChatState>(
      'sendMessage() adds user message and calls repository.send()',
      setUp: () {
        when(() => repository.send(any())).thenReturn(null);
      },
      build: () => ChatCubit(repository, notificationService),
      seed: () => const ChatState(
        connectionStatus: ChatConnectionStatus.connected,
        inputText: 'Hello, world!',
      ),
      act: (cubit) => cubit.sendMessage(),
      expect: () => [
        isA<ChatState>()
            .having((s) => s.messages.length, 'msg count', 1)
            .having((s) => s.messages.first.content, 'content', 'Hello, world!')
            .having((s) => s.inputText, 'input cleared', ''),
      ],
      verify: (_) {
        verify(() => repository.send('Hello, world!')).called(1);
      },
    );

    blocTest<ChatCubit, ChatState>(
      'does not send empty messages',
      build: () => ChatCubit(repository, notificationService),
      act: (cubit) => cubit.sendMessage(),
      expect: () => [],
    );

    blocTest<ChatCubit, ChatState>(
      'appends streaming tokens and transitions to streaming state',
      setUp: () {
        when(() => repository.connect()).thenAnswer((_) async {});
        when(() => repository.isConnected).thenReturn(true);
      },
      build: () => ChatCubit(repository, notificationService),
      act: (cubit) async {
        await cubit.connect();
        eventController.add(TokenEvent('Hello '));
        await Future.delayed(Duration.zero);
        eventController.add(TokenEvent('World'));
        await Future.delayed(Duration.zero);
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<ChatState>()
            .having((s) => s.connectionStatus, 'status',
                ChatConnectionStatus.connecting),
        isA<ChatState>()
            .having((s) => s.connectionStatus, 'status',
                ChatConnectionStatus.connected),
        isA<ChatState>()
            .having((s) => s.connectionStatus, 'status',
                ChatConnectionStatus.streaming)
            .having((s) => s.messages.last.content, 'content', 'Hello '),
        isA<ChatState>()
            .having((s) => s.connectionStatus, 'status',
                ChatConnectionStatus.streaming)
            .having((s) => s.messages.last.content, 'content', 'Hello World'),
      ],
    );

    blocTest<ChatCubit, ChatState>(
      'accumulates thinking deltas and sums the duration of each reasoning block',
      setUp: () {
        when(() => repository.connect()).thenAnswer((_) async {});
        when(() => repository.isConnected).thenReturn(true);
      },
      build: () => ChatCubit(repository, notificationService),
      act: (cubit) async {
        await cubit.connect();
        // A turn with a tool call produces one reasoning block per step.
        eventController.add(ThinkingEvent('Let me '));
        await Future.delayed(Duration.zero);
        eventController.add(ThinkingEvent('check.'));
        await Future.delayed(Duration.zero);
        eventController.add(ThinkingEndEvent(300));
        await Future.delayed(Duration.zero);
        eventController.add(ThinkingEvent('Got it.'));
        await Future.delayed(Duration.zero);
        eventController.add(ThinkingEndEvent(200));
        await Future.delayed(Duration.zero);
        eventController.add(TokenEvent('The answer.'));
        await Future.delayed(Duration.zero);
        eventController.add(DoneEvent(durationMs: 5000));
        await Future.delayed(Duration.zero);
      },
      wait: const Duration(milliseconds: 100),
      verify: (cubit) {
        final message = cubit.state.messages.last;
        expect(message.thinkingContent, 'Let me check.\n\nGot it.\n\n');
        expect(message.thinkingDuration, const Duration(milliseconds: 500));
        expect(message.content, 'The answer.');
        // The turn's own duration stays separate from time spent reasoning.
        expect(message.duration, const Duration(seconds: 5));
        expect(message.isStreaming, isFalse);
      },
    );

    blocTest<ChatCubit, ChatState>(
      'ThinkingEndEvent without a duration leaves thinkingDuration unset',
      setUp: () {
        when(() => repository.connect()).thenAnswer((_) async {});
        when(() => repository.isConnected).thenReturn(true);
      },
      build: () => ChatCubit(repository, notificationService),
      act: (cubit) async {
        await cubit.connect();
        eventController.add(ThinkingEvent('Hmm.'));
        await Future.delayed(Duration.zero);
        eventController.add(ThinkingEndEvent(null));
        await Future.delayed(Duration.zero);
      },
      wait: const Duration(milliseconds: 100),
      verify: (cubit) {
        final message = cubit.state.messages.last;
        expect(message.thinkingContent, 'Hmm.\n\n');
        expect(message.thinkingDuration, isNull);
      },
    );

    blocTest<ChatCubit, ChatState>(
      'DoneEvent finalizes streaming and returns to connected',
      setUp: () {
        when(() => repository.connect()).thenAnswer((_) async {});
        when(() => repository.isConnected).thenReturn(true);
      },
      build: () => ChatCubit(repository, notificationService),
      act: (cubit) async {
        await cubit.connect();
        eventController.add(TokenEvent('Hello'));
        await Future.delayed(Duration.zero);
        eventController.add(DoneEvent());
        await Future.delayed(Duration.zero);
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<ChatState>()
            .having((s) => s.connectionStatus, 'status',
                ChatConnectionStatus.connecting),
        isA<ChatState>()
            .having((s) => s.connectionStatus, 'status',
                ChatConnectionStatus.connected),
        isA<ChatState>()
            .having((s) => s.messages.last.content, 'content', 'Hello')
            .having((s) => s.messages.last.isStreaming, 'streaming', true),
        isA<ChatState>()
            .having((s) => s.connectionStatus, 'status',
                ChatConnectionStatus.connected)
            .having((s) => s.messages.last.isStreaming, 'streaming', false)
            .having((s) => s.messages.last.content, 'content', 'Hello'),
      ],
    );

    blocTest<ChatCubit, ChatState>(
      'disconnect() sets status to disconnected',
      build: () => ChatCubit(repository, notificationService),
      seed: () => const ChatState(
          connectionStatus: ChatConnectionStatus.connected),
      act: (cubit) => cubit.disconnect(),
      expect: () => [
        isA<ChatState>()
            .having((s) => s.connectionStatus, 'status',
                ChatConnectionStatus.disconnected),
      ],
    );

    blocTest<ChatCubit, ChatState>(
      'AuthFailedEvent sets disconnected with error and does not reconnect',
      setUp: () {
        when(() => repository.connect()).thenAnswer((_) async {});
        when(() => repository.isConnected).thenReturn(true);
      },
      build: () => ChatCubit(repository, notificationService),
      seed: () => const ChatState(
          connectionStatus: ChatConnectionStatus.connected),
      act: (cubit) async {
        await cubit.connect();
        eventController.add(AuthFailedEvent('Authentication failed'));
        await Future.delayed(Duration.zero);
      },
      wait: const Duration(milliseconds: 250),
      expect: () => [
        isA<ChatState>()
            .having((s) => s.connectionStatus, 'status',
                ChatConnectionStatus.connecting),
        isA<ChatState>()
            .having((s) => s.connectionStatus, 'status',
                ChatConnectionStatus.connected),
        isA<ChatState>()
            .having((s) => s.connectionStatus, 'status',
                ChatConnectionStatus.disconnected)
            .having((s) => s.errorMessage, 'error',
                'Authentication failed'),
      ],
      verify: (cubit) {
        // No subsequent connect() should be triggered.
        verify(() => repository.connect()).called(1);
      },
    );
  });
}
