import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:samantha/app/injection.dart';
import 'package:samantha/app/router.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/app/theme_mode_cubit.dart';
import 'package:samantha/features/notification/service/notification_service.dart';
import 'package:samantha/l10n/app_localizations.dart';

class SettingsWrapper extends StatefulWidget {
  final Widget child;

  const SettingsWrapper({required this.child, super.key});

  @override
  State<SettingsWrapper> createState() => _SettingsWrapperState();
}

class _SettingsWrapperState extends State<SettingsWrapper> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.dark;
  Locale? _locale;
  late final RouterConfig<Object> _routerConfig;

  @override
  void initState() {
    super.initState();
    _routerConfig = AppRouter().config();
    _loadSettings();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notificationService = getIt<NotificationService>();

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        notificationService.markStreamingOnBackground();
      case AppLifecycleState.resumed:
        notificationService.markForeground();
      default:
        break;
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? 2;
    final localeCode = prefs.getString('app_locale');

    setState(() {
      _themeMode = ThemeMode.values[themeIndex.clamp(0, ThemeMode.values.length - 1)];
      _locale = localeCode != null ? Locale(localeCode) : null;
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    setState(() => _themeMode = mode);
  }

  Future<void> _setLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove('app_locale');
    } else {
      await prefs.setString('app_locale', locale.languageCode);
    }
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScope(
      themeMode: _themeMode,
      locale: _locale,
      setThemeMode: _setThemeMode,
      setLocale: _setLocale,
      child: BlocProvider(
        create: (_) => ThemeModeCubit.initial(_themeMode),
        child: BlocBuilder<ThemeModeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp.router(
              title: 'Samantha',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: themeMode,
              routerConfig: _routerConfig,
              locale: _locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('en'),
                Locale('ka'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SettingsScope extends InheritedWidget {
  final ThemeMode themeMode;
  final Locale? locale;
  final ValueChanged<ThemeMode> setThemeMode;
  final ValueChanged<Locale?> setLocale;

  const _SettingsScope({
    required this.themeMode,
    required this.locale,
    required this.setThemeMode,
    required this.setLocale,
    required super.child,
  });

  static _SettingsScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_SettingsScope>()!;
  }

  @override
  bool updateShouldNotify(_SettingsScope old) {
    return themeMode != old.themeMode || locale != old.locale;
  }
}

extension SettingsX on BuildContext {
  ThemeMode get themeMode => _SettingsScope.of(this).themeMode;
  Locale? get selectedLocale => _SettingsScope.of(this).locale;
  void setThemeMode(ThemeMode mode) => _SettingsScope.of(this).setThemeMode(mode);
  void setLocale(Locale? locale) => _SettingsScope.of(this).setLocale(locale);
}
