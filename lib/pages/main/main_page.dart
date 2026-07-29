import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../common/widgets/app_chrome.dart';
import '../../utils/move_to_background.dart';
import '../../utils/storage.dart';
import '../home/hot_page.dart';
import '../home/recommend_page.dart';
import '../settings/settings_page.dart';
import 'main_controller.dart';

/// Android 主框架直接呈现两个内容入口和设置，避免额外占用顶部空间。
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late final MainController controller;

  static const _pages = <Widget>[RecommendPage(), HotPage(), SettingsPage()];

  @override
  void initState() {
    super.initState();
    controller = Get.put(MainController());
    controller.currentIndex.value = Pref.defaultHomeTab.clamp(0, 1);
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
        body: Obx(
          () => _FadeIndexedStack(
            index: controller.currentIndex.value,
            children: _pages,
          ),
        ),
        bottomNavigationBar: Obx(
          () => _FloatingNavigation(
            selectedIndex: controller.currentIndex.value,
            onSelected: controller.changeIndex,
          ),
        ),
      ),
    );
  }
}

class _FadeIndexedStack extends StatelessWidget {
  final int index;
  final List<Widget> children;

  const _FadeIndexedStack({required this.index, required this.children});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(children.length, (childIndex) {
        final active = childIndex == index;
        return IgnorePointer(
          ignoring: !active,
          child: AnimatedOpacity(
            opacity: active ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            child: TickerMode(enabled: active, child: children[childIndex]),
          ),
        );
      }),
    );
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
