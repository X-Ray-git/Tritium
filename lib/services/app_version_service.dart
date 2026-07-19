import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

abstract final class AppVersionService {
  static PackageInfo? _packageInfo;

  static Future<void> init() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (error) {
      debugPrint('Unable to read app version: $error');
    }
  }

  static String get version => _packageInfo?.version ?? '0.0.0';

  static String get buildNumber => _packageInfo?.buildNumber ?? '0';

  static String get displayVersion => '$version+$buildNumber';
}
