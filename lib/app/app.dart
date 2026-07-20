import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:samantha/app/injection.dart';
import 'package:samantha/app/router.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/app/theme_mode_cubit.dart';
import 'package:samantha/features/connection_settings/presentation/state/connection_settings_cubit.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/l10n/app_localizations.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final RouterConfig<Object> _routerConfig;

  @override
  void initState() {
    super.initState();
    _routerConfig = AppRouter().config();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<ConnectionSettingsCubit>()..load()),
        BlocProvider(create: (_) => getIt<ChatCubit>()),
        BlocProvider(create: (_) => ThemeModeCubit()),
      ],
      child: BlocBuilder<ThemeModeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp.router(
            title: 'Samantha',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            routerConfig: _routerConfig,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
            ],
          );
        },
      ),
    );
  }
}
