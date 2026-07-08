import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeCubit extends Cubit<ThemeMode> {
  ThemeModeCubit() : super(ThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('themeMode');
    if (value != null) {
      emit(value == 'light' ? ThemeMode.light : ThemeMode.dark);
    }
  }

  Future<void> toggle() async {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    emit(newMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', newMode == ThemeMode.light ? 'light' : 'dark');
  }
}
