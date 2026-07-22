import 'package:flutter/material.dart';
import 'package:samantha/app/app.dart';
import 'package:samantha/app/injection.dart';
import 'package:samantha/common/syntax_highlight.dart';
import 'package:samantha/features/notification/service/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await configureDependencies();
  registerHighlightLanguages();

  await getIt<NotificationService>().initialize();

  runApp(const App());
}
