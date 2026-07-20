import 'package:flutter/material.dart';
import 'package:samantha/app/app.dart';
import 'package:samantha/app/injection.dart';
import 'package:samantha/common/syntax_highlight.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await configureDependencies();
  registerHighlightLanguages();

  runApp(const App());
}
