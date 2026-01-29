import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'home_controller.dart';
import 'recommend_page.dart';
import 'hot_page.dart';
import 'follow_page.dart';
import '../main/main_page.dart';

/// 首页
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tritium'),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () {
            // 使用 GlobalKey 打开 MainPage 的 Drawer
            mainScaffoldKey.currentState?.openDrawer();
          },
          tooltip: '菜单',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              // TODO: 跳转搜索页
            },
            tooltip: '搜索',
          ),
        ],
        bottom: TabBar(
          controller: controller.tabController,
          tabs: const [
            Tab(text: '推荐'),
            Tab(text: '热榜'),
            Tab(text: '关注'),
          ],
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
        ),
      ),
      body: TabBarView(
        controller: controller.tabController,
        children: const [
          RecommendPage(),
          HotPage(),
          FollowPage(),
        ],
      ),
    );
  }
}
