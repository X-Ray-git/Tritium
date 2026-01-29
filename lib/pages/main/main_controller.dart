import 'dart:ui'; // For VoidCallback
import 'package:get/get.dart';

/// 主页面控制器
class MainController extends GetxController {
  /// 当前选中的底部导航索引
  final currentIndex = 0.obs;
  
  /// 滚动到顶部回调 (由子页面设置)
  VoidCallback? scrollToTopCallback;

  /// 切换底部导航
  void changeIndex(int index) {
    // 如果点击的是当前已选中的 Tab，触发滚动到顶部
    if (currentIndex.value == index && scrollToTopCallback != null) {
      scrollToTopCallback!();
    }
    currentIndex.value = index;
  }
}
