import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android 根页面返回时将整个任务移到后台，保留当前内存状态。
class MoveToBackground {
  static const MethodChannel _channel = MethodChannel(
    'io.github.xraygit.tritium/move_to_background',
  );

  static Future<void> moveTaskToBack() async {
    try {
      await _channel.invokeMethod<bool>('moveTaskToBack');
    } on MissingPluginException {
      // 非 Android 平台没有对应实现，保持默认的无操作行为。
    } catch (error) {
      debugPrint('Failed to move Tritium task to background: $error');
    }
  }
}
