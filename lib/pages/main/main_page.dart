import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../common/widgets/app_chrome.dart';
import '../home/home_page.dart';
import '../settings/settings_page.dart';
import 'main_controller.dart';

/// Android 主框架只承载真实可用的“内容”和“设置”两个区域。
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late final MainController controller;

  static const _pages = <Widget>[HomePage(), SettingsPage()];

  @override
  void initState() {
    super.initState();
    controller = Get.put(MainController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: TritiumBlurAppBar(
        title: Obx(
          () => Text(
            controller.currentIndex.value == 0 ? 'Tritium' : '设置',
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
          icon: Icons.article_outlined,
          selectedIcon: Icons.article_rounded,
          label: '内容',
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
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, safeBottom + 12),
      child: SizedBox(
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.34 : 0.13),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: dark ? 0.86 : 0.82),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.42),
                    width: 0.8,
                  ),
                ),
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
                                width: 72,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? colors.primary.withValues(alpha: 0.88)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Icon(
                                  selected ? item.selectedIcon : item.icon,
                                  size: 24,
                                  color: selected
                                      ? colors.onPrimary
                                      : colors.onSurfaceVariant,
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
        ),
      ),
    );
  }
}
