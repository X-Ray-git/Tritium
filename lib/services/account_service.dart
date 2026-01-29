import 'dart:convert';
import 'package:get/get.dart';

import '../http/init.dart';
import '../common/constants/constants.dart';
import '../utils/storage.dart';
import '../models/user/user_info.dart';

/// 账户服务
class AccountService extends GetxService {
  static AccountService get to => Get.find<AccountService>();

  /// 当前用户信息
  final Rx<UserInfo?> currentUser = Rx<UserInfo?>(null);

  /// 是否已登录
  bool get isLoggedIn => Pref.isLoggedIn && Pref.cookies != null;

  @override
  void onInit() {
    super.onInit();
    _loadUserInfo();
  }

  /// 加载缓存的用户信息
  void _loadUserInfo() {
    final userInfoJson = Pref.userInfo;
    if (userInfoJson != null) {
      try {
        final json = jsonDecode(userInfoJson);
        currentUser.value = UserInfo.fromJson(json);
      } catch (e) {
        // 解析失败，清除数据
        Pref.userInfo = null;
      }
    }
  }

  /// 设置登录 Cookie
  Future<bool> setLoginCookie(String cookies) async {
    Pref.cookies = cookies;
    
    // 获取用户信息验证登录状态
    final success = await fetchUserInfo();
    if (success) {
      Pref.isLoggedIn = true;
      return true;
    } else {
      // 登录失败，清除 Cookie
      Pref.cookies = null;
      return false;
    }
  }

  /// 获取当前用户信息
  Future<bool> fetchUserInfo() async {
    try {
      final response = await Request().get(ApiPaths.me);
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && !data.containsKey('error')) {
          final userInfo = UserInfo.fromJson(data);
          currentUser.value = userInfo;
          Pref.userInfo = jsonEncode(data);
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 登出
  Future<void> logout() async {
    // 清除用户数据
    await Pref.clearUserData();
    currentUser.value = null;
  }

  /// 检查登录状态
  Future<bool> checkLoginStatus() async {
    if (!isLoggedIn) return false;
    
    // 验证登录状态是否有效
    return await fetchUserInfo();
  }
}
