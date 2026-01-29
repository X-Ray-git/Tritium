import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../common/constants/constants.dart';

/// 全局存储管理类
class GStorage {
  GStorage._();

  static late Box _settingBox;
  static late Box _userBox;
  static late Box _cacheBox;

  /// 初始化存储
  static Future<void> init() async {
    if (!kIsWeb) {
      final dir = await getApplicationSupportDirectory();
      final path = '${dir.path}/hive';
      // 确保目录存在
      await Directory(path).create(recursive: true);
      await Hive.initFlutter(path);
    } else {
      await Hive.initFlutter();
    }

    // 打开存储 Box
    _settingBox = await Hive.openBox('settings');
    _userBox = await Hive.openBox('user');
    _cacheBox = await Hive.openBox('cache');
  }

  /// 设置 Box
  static Box get setting => _settingBox;

  /// 用户 Box
  static Box get user => _userBox;

  /// 缓存 Box
  static Box get cache => _cacheBox;

  /// 关闭所有 Box
  static Future<void> close() async {
    await _settingBox.close();
    await _userBox.close();
    await _cacheBox.close();
  }

  /// 清除所有数据
  static Future<void> clear() async {
    await _settingBox.clear();
    await _userBox.clear();
    await _cacheBox.clear();
  }
}

/// 偏好设置快捷访问
class Pref {
  Pref._();

  // ============ 主题设置 ============

  /// 主题模式
  static ThemeMode get themeMode {
    final value = GStorage.setting.get(StorageKeys.themeMode, defaultValue: 0);
    return ThemeMode.values[value];
  }

  static set themeMode(ThemeMode mode) {
    GStorage.setting.put(StorageKeys.themeMode, mode.index);
  }

  /// 是否启用动态取色
  static bool get dynamicColor {
    return GStorage.setting.get(StorageKeys.dynamicColor, defaultValue: true);
  }

  static set dynamicColor(bool value) {
    GStorage.setting.put(StorageKeys.dynamicColor, value);
  }

  /// 自定义主题颜色索引
  static int get customColor {
    return GStorage.setting.get(StorageKeys.customColor, defaultValue: 0);
  }

  static set customColor(int value) {
    GStorage.setting.put(StorageKeys.customColor, value);
  }

  // ============ 用户设置 ============

  /// 是否已登录
  static bool get isLoggedIn {
    return GStorage.user.get(StorageKeys.isLoggedIn, defaultValue: false);
  }

  static set isLoggedIn(bool value) {
    GStorage.user.put(StorageKeys.isLoggedIn, value);
  }

  /// Cookie
  static String? get cookies {
    return GStorage.user.get(StorageKeys.cookies);
  }

  static set cookies(String? value) {
    if (value == null) {
      GStorage.user.delete(StorageKeys.cookies);
    } else {
      GStorage.user.put(StorageKeys.cookies, value);
    }
  }

  /// 用户信息 (JSON 字符串)
  static String? get userInfo {
    return GStorage.user.get(StorageKeys.userInfo);
  }

  static set userInfo(String? value) {
    if (value == null) {
      GStorage.user.delete(StorageKeys.userInfo);
    } else {
      GStorage.user.put(StorageKeys.userInfo, value);
    }
  }

  /// 清除用户数据
  static Future<void> clearUserData() async {
    await GStorage.user.clear();
  }

  // ============ 通用设置 ============

  /// 默认回答排序: default (默认/热度), created (时间)
  static String get defaultAnswerSort {
    return GStorage.setting.get(StorageKeys.defaultAnswerSort, defaultValue: 'default');
  }

  static set defaultAnswerSort(String value) {
    GStorage.setting.put(StorageKeys.defaultAnswerSort, value);
  }

  /// 默认评论排序: score (热度), ts (时间)
  static String get defaultCommentSort {
    return GStorage.setting.get(StorageKeys.defaultCommentSort, defaultValue: 'score');
  }

  static set defaultCommentSort(String value) {
    GStorage.setting.put(StorageKeys.defaultCommentSort, value);
  }

  /// 默认启动页: 0 (推荐), 1 (热榜)
  static int get defaultHomeTab {
    return GStorage.setting.get(StorageKeys.defaultHomeTab, defaultValue: 0);
  }

  static set defaultHomeTab(int value) {
    GStorage.setting.put(StorageKeys.defaultHomeTab, value);
  }

  // ============ 外观效果设置 ============



  // ============ 交互设置 ============

  /// 是否启用滑动振动反馈
  static bool get enableSwipeHaptics {
    return GStorage.setting.get(StorageKeys.enableSwipeHaptics, defaultValue: false);
  }

  static set enableSwipeHaptics(bool value) {
    GStorage.setting.put(StorageKeys.enableSwipeHaptics, value);
  }
}
