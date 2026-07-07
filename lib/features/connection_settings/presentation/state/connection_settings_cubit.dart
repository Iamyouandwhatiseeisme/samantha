import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:samantha/features/connection_settings/data/connection_api.dart';
import 'package:samantha/features/connection_settings/data/connection_settings_repository.dart';
import 'package:samantha/features/connection_settings/presentation/state/connection_settings_state.dart';

@injectable
class ConnectionSettingsCubit extends Cubit<ConnectionSettingsState> {
  final ConnectionSettingsRepository _repository;
  final ConnectionApi _connectionApi;

  ConnectionSettingsCubit(this._repository, this._connectionApi)
      : super(ConnectionSettingsInitial());

  Future<void> load() async {
    emit(ConnectionSettingsLoading());
    final host = await _repository.getHost() ?? '';
    final authToken = await _repository.getAuthToken() ?? '';
    emit(ConnectionSettingsLoaded(host: host, authToken: authToken));
  }

  Future<void> save(String host, String authToken) async {
    await _repository.saveHost(host);
    await _repository.saveAuthToken(authToken);
    emit(ConnectionSettingsLoaded(host: host, authToken: authToken));
  }

  void updateHost(String host) {
    final authToken = _currentAuthToken();
    emit(ConnectionSettingsLoaded(host: host, authToken: authToken));
  }

  void updateAuthToken(String token) {
    final host = _currentHost();
    emit(ConnectionSettingsLoaded(host: host, authToken: token));
  }

  Future<void> testConnection(String host) async {
    final authToken = _currentAuthToken();
    emit(ConnectionSettingsTesting(host: host, authToken: authToken));

    try {
      final success = await _connectionApi.checkHealth(host);
      if (success) {
        emit(ConnectionSettingsTestSuccess(host: host, authToken: authToken));
      } else {
        emit(ConnectionSettingsTestFailure(
          host: host,
          authToken: authToken,
          message: 'Health check failed',
        ));
      }
    } catch (e) {
      emit(ConnectionSettingsTestFailure(
        host: host,
        authToken: authToken,
        message: e.toString(),
      ));
    }
  }

  String _currentHost() {
    return switch (state) {
      ConnectionSettingsLoaded(host: final h) => h,
      ConnectionSettingsTesting(host: final h) => h,
      ConnectionSettingsTestSuccess(host: final h) => h,
      ConnectionSettingsTestFailure(host: final h) => h,
      _ => '',
    };
  }

  String _currentAuthToken() {
    return switch (state) {
      ConnectionSettingsLoaded(authToken: final t) => t,
      ConnectionSettingsTesting(authToken: final t) => t,
      ConnectionSettingsTestSuccess(authToken: final t) => t,
      ConnectionSettingsTestFailure(authToken: final t) => t,
      _ => '',
    };
  }
}
