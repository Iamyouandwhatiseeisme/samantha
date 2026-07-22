import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/app/theme_mode_cubit.dart';
import 'package:samantha/features/chat/data/chat_repository.dart';
import 'package:samantha/features/chat/data/chat_socket_client.dart';
import 'package:samantha/features/chat/presentation/chat_screen.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/notification/service/notification_service.dart';
import 'package:samantha/services/background_task_service.dart';

class MockChatRepository extends Mock implements ChatRepository {}
class MockNotificationService extends Mock implements NotificationService {}
class MockBackgroundTaskService extends Mock implements BackgroundTaskService {}

void main() {
  late MockChatRepository repository;
  late MockNotificationService notificationService;
  late MockBackgroundTaskService backgroundTaskService;
  late StreamController<ChatEvent> eventController;

  setUp(() {
    repository = MockChatRepository();
    notificationService = MockNotificationService();
    backgroundTaskService = MockBackgroundTaskService();
    eventController = StreamController<ChatEvent>.broadcast();
    when(() => repository.events).thenAnswer((_) => eventController.stream);
    when(() => repository.disconnect()).thenAnswer((_) async {});
    when(() => repository.connect()).thenAnswer((_) async {});
    when(() => repository.send(any())).thenReturn(null);
    when(() => repository.getProjectPath()).thenAnswer((_) async => null);
    when(() => repository.getSessionId()).thenAnswer((_) async => null);
    when(() => repository.setProject(any())).thenReturn(null);
    when(() => repository.setSession(any(), any())).thenReturn(null);
    when(() => notificationService.shouldNotifyOnCompletion).thenReturn(false);
    when(() => backgroundTaskService.begin()).thenAnswer((_) async {});
    when(() => backgroundTaskService.end()).thenAnswer((_) async {});
  });

  tearDown(() {
    eventController.close();
  });

  testWidgets('ChatScreen renders messages without layout assertion',
      (tester) async {
    final cubit = ChatCubit(repository, notificationService, backgroundTaskService);
    addTearDown(cubit.close);

    // Seed two user messages to exercise the ListView layout.
    cubit.updateInput('hi');
    cubit.sendMessage();
    cubit.updateInput('hello');
    cubit.sendMessage();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ChatCubit>.value(value: cubit),
            BlocProvider<ThemeModeCubit>.value(value: ThemeModeCubit()),
          ],
          child: const ChatScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('hi'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}