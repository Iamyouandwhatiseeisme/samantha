import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
class NotificationSettingsRepository {
  static const _permissionRequestedKey = 'notification_permission_requested';
  static const _permissionGrantedKey = 'notification_permission_granted';

  final SharedPreferences _prefs;

  NotificationSettingsRepository(this._prefs);

  Future<void> markPermissionRequested() async {
    await _prefs.setBool(_permissionRequestedKey, true);
  }

  bool hasPermissionBeenRequested() {
    return _prefs.getBool(_permissionRequestedKey) ?? false;
  }

  Future<void> savePermissionGranted(bool granted) async {
    await _prefs.setBool(_permissionGrantedKey, granted);
  }

  bool isPermissionGranted() {
    return _prefs.getBool(_permissionGrantedKey) ?? false;
  }
}
