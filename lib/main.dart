import 'package:flutter/material.dart';
import 'package:samantha/app/app.dart';
import 'package:samantha/app/injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await configureDependencies();

  runApp(const App());
}
