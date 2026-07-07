import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/app/injection.dart';
import 'package:samantha/app/router.dart';
import 'package:samantha/features/connection_settings/presentation/state/connection_settings_cubit.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<ConnectionSettingsCubit>()..load()),
        BlocProvider(create: (_) => getIt<ChatCubit>()),
      ],
      child: MaterialApp.router(
        title: 'Samantha',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        routerConfig: AppRouter().config(),
      ),
    );
  }
}
