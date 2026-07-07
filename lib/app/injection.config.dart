// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:dio/dio.dart' as _i361;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

import '../features/chat/data/chat_repository.dart' as _i320;
import '../features/chat/data/chat_socket_client.dart' as _i865;
import '../features/chat/presentation/state/chat_cubit.dart' as _i713;
import '../features/connection_settings/data/connection_api.dart' as _i100;
import '../features/connection_settings/data/connection_settings_repository.dart'
    as _i533;
import '../features/connection_settings/presentation/state/connection_settings_cubit.dart'
    as _i99;
import 'module.dart' as _i946;

// initializes the registration of main-scope dependencies inside of GetIt
Future<_i174.GetIt> init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) async {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  final appModule = _$AppModule();
  gh.factory<_i865.ChatSocketClient>(() => _i865.ChatSocketClient());
  gh.lazySingleton<_i361.Dio>(() => appModule.dio);
  await gh.lazySingletonAsync<_i460.SharedPreferences>(
    () => appModule.prefs,
    preResolve: true,
  );
  gh.lazySingleton<_i100.ConnectionApi>(
    () => _i100.ConnectionApi(gh<_i361.Dio>()),
  );
  gh.lazySingleton<_i533.ConnectionSettingsRepository>(
    () => _i533.ConnectionSettingsRepository(gh<_i460.SharedPreferences>()),
  );
  gh.factory<_i99.ConnectionSettingsCubit>(
    () => _i99.ConnectionSettingsCubit(
      gh<_i533.ConnectionSettingsRepository>(),
      gh<_i100.ConnectionApi>(),
    ),
  );
  gh.lazySingleton<_i320.ChatRepository>(
    () => _i320.ChatRepository(
      gh<_i865.ChatSocketClient>(),
      gh<_i533.ConnectionSettingsRepository>(),
    ),
  );
  gh.factory<_i713.ChatCubit>(
    () => _i713.ChatCubit(gh<_i320.ChatRepository>()),
  );
  return getIt;
}

class _$AppModule extends _i946.AppModule {}
