import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'home_controller.dart';
import 'recommend_page.dart';
import 'hot_page.dart';

/// 首页
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Material(
          color: colorScheme.surface,
          child: TabBar(
            controller: controller.tabController,
            tabs: const [
              Tab(text: '推荐'),
              Tab(text: '热榜'),
            ],
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: controller.tabController,
            children: const [RecommendPage(), HotPage()],
          ),
        ),
      ],
    );
  }
}
