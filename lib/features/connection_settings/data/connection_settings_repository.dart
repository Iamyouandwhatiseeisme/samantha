import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
class ConnectionSettingsRepository {
  static const _hostKey = 'opencode_host';
  static const _authTokenKey = 'opencode_auth_token';

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
}
