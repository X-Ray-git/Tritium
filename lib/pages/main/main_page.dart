import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../common/widgets/app_chrome.dart';
import '../../utils/move_to_background.dart';
import '../../utils/storage.dart';
import '../home/hot_page.dart';
import '../home/recommend_page.dart';
import '../settings/settings_page.dart';
import 'main_controller.dart';

/// Android 主框架：三个主页（推荐/热榜/设置）通过跟手的 PageView 左右滑动切换，
/// 底部导航点击使用动画切页；三个页面显式保活，切换后不重新请求、不丢滚动位置。
class MainPage extends StatefulWidget {
  final List<Widget>? pagesForTesting;

  const MainPage({super.key, @visibleForTesting this.pagesForTesting});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late final MainController controller;
  late final PageController _pageController;
  late final List<Widget> _pages;

  /// 编程式切页（底部导航点击）进行中：期间忽略 onPageChanged 的中间页同步。
  bool _programmaticJump = false;

  @override
  void initState() {
    super.initState();
    controller = Get.put(MainController());
    final initialIndex = Pref.defaultHomeTab.clamp(0, 1);
    controller.currentIndex.value = initialIndex;
    _pageController = PageController(initialPage: initialIndex);
    _pages =
        (widget.pagesForTesting ??
                const <Widget>[RecommendPage(), HotPage(), SettingsPage()])
            .map((page) => _KeepAlivePage(child: page))
            .toList(growable: false);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    // 滑动选中：同步导航栏与 AppBar 标题。
    if (_programmaticJump) return;
    if (controller.currentIndex.value != index) {
      controller.currentIndex.value = index;
    }
  }

  bool _handleScrollEnd(ScrollEndNotification notification) {
    if (notification.metrics.axis != Axis.horizontal) return false;
    // 滑动或动画落定后，以实际停靠页为准。
    _programmaticJump = false;
    final index =
        _pageController.page?.round() ?? controller.currentIndex.value;
    if (controller.currentIndex.value != index) {
      controller.currentIndex.value = index;
    }
    return false;
  }

  void _onNavigationSelected(int index) {
    if (controller.currentIndex.value == index) {
      // 重复点击当前导航按钮滚回顶部。
      controller.changeIndex(index);
      return;
    }
    // 点击选中：更新选中态并以动画切页。
    controller.currentIndex.value = index;
    _programmaticJump = true;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) MoveToBackground.moveTaskToBack();
      },
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: TritiumBlurAppBar(
          title: Obx(
            () => Text(
              controller.currentIndex.value == 2 ? '设置' : 'Tritium',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        body: NotificationListener<ScrollEndNotification>(
          onNotification: _handleScrollEnd,
          child: Obx(
            () => PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  // 离屏页面暂停动画（保留状态），避免加载指示器等持续动画
                  // 在不可见时空转。
                  TickerMode(
                    enabled: controller.currentIndex.value == i,
                    child: _pages[i],
                  ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Obx(
          () => _FloatingNavigation(
            selectedIndex: controller.currentIndex.value,
            onSelected: _onNavigationSelected,
          ),
        ),
      ),
    );
  }
}

/// 三个主页显式保活：离开视口后仍保留滚动位置与已加载数据。
class _KeepAlivePage extends StatefulWidget {
  final Widget child;

  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _FloatingNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _FloatingNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  static const _items =
      <({IconData icon, IconData selectedIcon, String label})>[
        (
          icon: Icons.auto_awesome_outlined,
          selectedIcon: Icons.auto_awesome_rounded,
          label: '推荐',
        ),
        (
          icon: Icons.local_fire_department_outlined,
          selectedIcon: Icons.local_fire_department_rounded,
          label: '热榜',
        ),
        (
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings_rounded,
          label: '设置',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SizedBox(
        height: 56,
        child: CustomPaint(
          painter: TritiumNavigationOuterShadowPainter(dark: dark),
          child: TritiumGlassNavigationSurface(
            child: Row(
              children: List.generate(_items.length, (index) {
                final item = _items[index];
                final selected = selectedIndex == index;
                return Expanded(
                  child: Semantics(
                    selected: selected,
                    button: true,
                    label: item.label,
                    child: Tooltip(
                      message: item.label,
                      child: InkWell(
                        onTap: () => onSelected(index),
                        customBorder: const StadiumBorder(),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            width: 52,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: AnimatedScale(
                              scale: selected ? 1 : 0.96,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutBack,
                              child: Icon(
                                selected ? item.selectedIcon : item.icon,
                                size: 24,
                                color: selected
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
