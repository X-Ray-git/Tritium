import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'main_controller.dart';
import '../home/home_page.dart';
import '../../router/app_pages.dart';
import '../../services/account_service.dart';

/// 全局 Scaffold Key，用于控制 Drawer
final GlobalKey<ScaffoldState> mainScaffoldKey = GlobalKey<ScaffoldState>();

/// 主页面
class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MainController());
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: mainScaffoldKey,
      extendBody: false, // 不再需要延伸到底部导航栏下方
      body: Obx(() {
        switch (controller.currentIndex.value) {
          case 0:
            return const HomePage();
          case 1:
            return const _DiscoverPage();
          case 2:
            return const _NotificationsPage();
          case 3:
            return const _MinePage();
          default:
            return const HomePage();
        }
      }),
      bottomNavigationBar: Obx(() => NavigationBar(
            selectedIndex: controller.currentIndex.value,
            onDestinationSelected: controller.changeIndex,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: '首页',
              ),
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: '发现',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications_rounded),
                label: '通知',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: '我的',
              ),
            ],
          )),
      drawer: _buildDrawer(context, colorScheme),
    );
  }

  /// 构建侧边抽屉
  Widget _buildDrawer(BuildContext context, ColorScheme colorScheme) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // 用户信息区域
            _buildUserHeader(context, colorScheme),
            const Divider(),
            // 菜单列表
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    icon: Icons.bookmark_outline_rounded,
                    label: '收藏',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: 跳转收藏页
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.history_rounded,
                    label: '历史',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: 跳转历史页
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.download_outlined,
                    label: '本地',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: 跳转本地页
                    },
                  ),
                  const Divider(),
                  _buildDrawerItem(
                    icon: Icons.settings_outlined,
                    label: '设置',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(Routes.settings);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 用户头部信息
  Widget _buildUserHeader(BuildContext context, ColorScheme colorScheme) {
    return Obx(() {
      final accountService = Get.find<AccountService>();
      final user = accountService.currentUser.value;
      final isLoggedIn = accountService.isLoggedIn;

      return InkWell(
        onTap: () {
          Navigator.pop(context);
          if (!isLoggedIn) {
            Get.toNamed(Routes.login);
          } else {
            // TODO: 跳转个人主页
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 头像
              CircleAvatar(
                radius: 32,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: user?.avatar.isNotEmpty == true
                    ? NetworkImage(user!.avatar)
                    : null,
                child: user?.avatar.isNotEmpty != true
                    ? Icon(
                        Icons.person_rounded,
                        size: 32,
                        color: colorScheme.onPrimaryContainer,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // 用户名和签名
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoggedIn ? (user?.name ?? '未知用户') : '点击登录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (isLoggedIn && user?.headline != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        user!.headline!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 登出按钮
              if (isLoggedIn)
                IconButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Get.find<AccountService>().logout();
                  },
                  icon: Icon(
                    Icons.logout_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  tooltip: '登出',
                ),
            ],
          ),
        ),
      );
    });
  }

  /// 抽屉菜单项
  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}

/// 发现页（占位）
class _DiscoverPage extends StatelessWidget {
  const _DiscoverPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发现'),
      ),
      body: const Center(
        child: Text('发现页面开发中...'),
      ),
    );
  }
}

/// 通知页（占位）
class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
      ),
      body: const Center(
        child: Text('通知页面开发中...'),
      ),
    );
  }
}

/// 我的页（占位）
class _MinePage extends StatelessWidget {
  const _MinePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
      ),
      body: const Center(
        child: Text('我的页面开发中...'),
      ),
    );
  }
}
