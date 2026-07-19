import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../common/widgets/app_chrome.dart';
import '../../router/app_pages.dart';
import '../../services/account_service.dart';
import '../../services/app_version_service.dart';
import '../../utils/storage.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        88 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _sectionHeader(
          context,
          icon: Icons.person_outline_rounded,
          title: '账户',
          subtitle: '登录仅用于读取需要账户状态的知乎内容',
        ),
        _accountPanel(context),
        const SizedBox(height: 20),
        _sectionHeader(
          context,
          icon: Icons.tune_rounded,
          title: '内容',
          subtitle: '首页、回答和评论的默认阅读方式',
        ),
        TritiumPanel(
          child: Column(
            children: [
              _tile(
                icon: Icons.start_rounded,
                title: '默认内容页',
                subtitle: Pref.defaultHomeTab == 0 ? '推荐' : '热榜',
                onTap: _selectHomeTab,
              ),
              _divider(),
              _tile(
                icon: Icons.sort_rounded,
                title: '回答排序',
                subtitle: Pref.defaultAnswerSort == 'default' ? '按热度' : '按时间',
                onTap: _selectAnswerSort,
              ),
              _divider(),
              _tile(
                icon: Icons.comment_outlined,
                title: '评论排序',
                subtitle: Pref.defaultCommentSort == 'score' ? '按热度' : '按时间',
                onTap: _selectCommentSort,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionHeader(
          context,
          icon: Icons.palette_outlined,
          title: '外观',
          subtitle: 'Tritium 固定使用 #3961FF 品牌色',
        ),
        TritiumPanel(
          child: Column(
            children: [
              _tile(
                icon: Icons.brightness_6_rounded,
                title: '显示模式',
                subtitle: _themeModeLabel(Pref.themeMode),
                onTap: _selectThemeMode,
              ),
              _divider(),
              _tile(
                icon: Icons.speed_rounded,
                title: '屏幕刷新率',
                subtitle: '选择设备支持的显示模式',
                onTap: () => Get.toNamed(Routes.displayMode),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionHeader(
          context,
          icon: Icons.touch_app_outlined,
          title: '交互',
          subtitle: '阅读过程中的反馈偏好',
        ),
        TritiumPanel(
          child: SwitchListTile(
            secondary: const Icon(Icons.vibration_rounded),
            title: const Text('滑动振动反馈'),
            subtitle: const Text('切换回答时提供轻触反馈'),
            value: Pref.enableSwipeHaptics,
            onChanged: (value) {
              Pref.enableSwipeHaptics = value;
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: 20),
        _sectionHeader(
          context,
          icon: Icons.info_outline_rounded,
          title: '关于',
          subtitle: '非官方知乎第三方阅读客户端',
        ),
        TritiumPanel(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              const Icon(Icons.apps_rounded),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Tritium',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                AppVersionService.displayVersion,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return body;
  }

  Widget _accountPanel(BuildContext context) {
    return Obx(() {
      final service = AccountService.to;
      final user = service.currentUser.value;
      final loggedIn = service.isLoggedIn;
      return TritiumPanel(
        onTap: loggedIn ? null : () => Get.toNamed(Routes.login),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: user?.avatar.isNotEmpty == true
                  ? NetworkImage(user!.avatar)
                  : null,
              child: user?.avatar.isNotEmpty == true
                  ? null
                  : Icon(
                      Icons.person_rounded,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loggedIn ? (user?.name ?? '已登录') : '登录知乎',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    loggedIn ? (user?.headline ?? '账户信息已保存在本机') : '点击打开知乎登录页面',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (loggedIn)
              IconButton(
                tooltip: '退出登录',
                onPressed: () async {
                  await service.logout();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.logout_rounded),
              )
            else
              const Icon(Icons.chevron_right_rounded),
          ],
        ),
      );
    });
  }

  Widget _sectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: colors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  Widget _divider() => const Divider(indent: 56);

  String _themeModeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => '跟随系统',
    ThemeMode.light => '浅色',
    ThemeMode.dark => '深色',
  };

  Future<T?> _select<T>({
    required String title,
    required T current,
    required List<T> options,
    required String Function(T) labelFor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        return TritiumGlassSheet(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                ...options.map((option) {
                  final selected = option == current;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ListTile(
                      selected: selected,
                      selectedTileColor: colors.primary.withValues(alpha: 0.11),
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(labelFor(option)),
                      trailing: selected
                          ? Icon(Icons.check_rounded, color: colors.primary)
                          : null,
                      onTap: () => Navigator.pop(sheetContext, option),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectThemeMode() async {
    final value = await _select<ThemeMode>(
      title: '显示模式',
      current: Pref.themeMode,
      options: ThemeMode.values,
      labelFor: _themeModeLabel,
    );
    if (value == null) return;
    Pref.themeMode = value;
    if (mounted) setState(() {});
  }

  Future<void> _selectHomeTab() async {
    final value = await _select<int>(
      title: '默认内容页',
      current: Pref.defaultHomeTab,
      options: const [0, 1],
      labelFor: (value) => value == 0 ? '推荐' : '热榜',
    );
    if (value == null) return;
    Pref.defaultHomeTab = value;
    if (mounted) setState(() {});
  }

  Future<void> _selectAnswerSort() async {
    final value = await _select<String>(
      title: '回答排序',
      current: Pref.defaultAnswerSort,
      options: const ['default', 'created'],
      labelFor: (value) => value == 'default' ? '按热度' : '按时间',
    );
    if (value == null) return;
    Pref.defaultAnswerSort = value;
    if (mounted) setState(() {});
  }

  Future<void> _selectCommentSort() async {
    final value = await _select<String>(
      title: '评论排序',
      current: Pref.defaultCommentSort,
      options: const ['score', 'ts'],
      labelFor: (value) => value == 'score' ? '按热度' : '按时间',
    );
    if (value == null) return;
    Pref.defaultCommentSort = value;
    if (mounted) setState(() {});
  }
}
