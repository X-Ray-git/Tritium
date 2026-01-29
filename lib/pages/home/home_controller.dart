import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../utils/storage.dart';

/// 首页控制器
class HomeController extends GetxController with GetSingleTickerProviderStateMixin {
  late TabController tabController;

  /// 当前 Tab 索引
  final currentTabIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    final initialIndex = Pref.defaultHomeTab;
    tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    currentTabIndex.value = initialIndex; // Sync observable
    tabController.addListener(() {
      currentTabIndex.value = tabController.index;
    });
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }
}
