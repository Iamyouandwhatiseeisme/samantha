import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';
import 'package:samantha/features/notification/data/notification_settings_repository.dart';

@lazySingleton
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final NotificationSettingsRepository _settings;

  bool _initialized = false;
  bool _isBackgrounded = false;
  bool _wasStreamingWhenBackgrounded = false;

  NotificationService(this._settings);

  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (!_initialized) await initialize();

    final result = await _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final granted = result ?? false;
    await _settings.markPermissionRequested();
    await _settings.savePermissionGranted(granted);
    return granted;
  }

  bool get isEnabled => _settings.isPermissionGranted();

  void markStreamingOnBackground() {
    _isBackgrounded = true;
    _wasStreamingWhenBackgrounded = true;
  }

  void markForeground() {
    _isBackgrounded = false;
    _wasStreamingWhenBackgrounded = false;
  }

  bool get shouldNotifyOnCompletion => _isBackgrounded && _wasStreamingWhenBackgrounded && isEnabled;

  Future<void> sendCompletionNotification() async {
    if (!_initialized) await initialize();
    if (!isEnabled) return;

    const android = AndroidNotificationDetails(
      'completion_channel',
      'Completion Notifications',
      channelDescription: 'Notifies when a long-running AI response completes',
      importance: Importance.high,
      priority: Priority.high,
    );

    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      0,
      'Response Complete',
      'Your conversation response has finished.',
      const NotificationDetails(android: android, iOS: ios),
    );
  }
}
