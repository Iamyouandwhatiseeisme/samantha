import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

@injectable
class BackgroundTaskService {
  static const _channel = MethodChannel('com.samantha/background_task');

  int? _taskId;

  Future<void> begin() async {
    try {
      final id = await _channel.invokeMethod<int>('beginBackgroundTask');
      if (id != null) {
        _taskId = id;
      }
    } catch (_) {}
  }

  Future<void> end() async {
    final taskId = _taskId;
    if (taskId == null) return;
    try {
      await _channel.invokeMethod('endBackgroundTask', {'taskId': taskId});
    } catch (_) {}
    _taskId = null;
  }
}
