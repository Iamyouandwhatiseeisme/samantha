import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
class ConnectionSettingsRepository {
  static const _hostKey = 'opencode_host';
  static const _authTokenKey = 'opencode_auth_token';
  static const _projectPathKey = 'opencode_project_path';
  static const _sessionIdKey = 'opencode_session_id';

  final SharedPreferences _prefs;

  ConnectionSettingsRepository(this._prefs);

  Future<void> saveHost(String host) async {
    await _prefs.setString(_hostKey, host);
  }

  Future<String?> getHost() async {
    return _prefs.getString(_hostKey);
  }

  Future<void> saveAuthToken(String token) async {
    await _prefs.setString(_authTokenKey, token);
  }

  Future<String?> getAuthToken() async {
    return _prefs.getString(_authTokenKey);
  }

  Future<void> saveProjectPath(String path) async {
    await _prefs.setString(_projectPathKey, path);
  }

  Future<String?> getProjectPath() async {
    return _prefs.getString(_projectPathKey);
  }

  Future<void> saveSessionId(String? id) async {
    if (id != null) {
      await _prefs.setString(_sessionIdKey, id);
    } else {
      await _prefs.remove(_sessionIdKey);
    }
  }

  Future<String?> getSessionId() async {
    return _prefs.getString(_sessionIdKey);
  }
}
