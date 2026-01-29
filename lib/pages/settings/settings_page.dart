import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../common/theme/theme_color_type.dart';
import '../../utils/storage.dart';
import '../../router/app_pages.dart';

/// 设置页面
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // 通用设置
          _buildSection(
            title: '通用',
            children: [
              // 默认启动页
              ListTile(
                leading: const Icon(Icons.start_rounded),
                title: const Text('默认启动页'),
                subtitle: Text(Pref.defaultHomeTab == 0 ? '推荐' : '热榜'), // currently only 2 options relevant
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showHomeTabDialog(context),
              ),
              // 回答排序
              ListTile(
                leading: const Icon(Icons.sort_rounded),
                title: const Text('默认回答排序'),
                subtitle: Text(Pref.defaultAnswerSort == 'default' ? '默认 (热度)' : '按时间 (最新)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAnswerSortDialog(context),
              ),
              // 评论排序
              ListTile(
                leading: const Icon(Icons.comment_outlined),
                title: const Text('默认评论排序'),
                subtitle: Text(_getCommentSortLabel(Pref.defaultCommentSort)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCommentSortDialog(context),
              ),
              // 屏幕帧率
              ListTile(
                leading: const Icon(Icons.speed_rounded),
                title: const Text('屏幕帧率'),
                subtitle: const Text('设置屏幕刷新率'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.toNamed(Routes.displayMode),
              ),
            ],
          ),
          // 外观设置
          _buildSection(
            title: '外观',
            children: [
              // 主题模式
              ListTile(
                leading: const Icon(Icons.brightness_6_rounded),
                title: const Text('主题模式'),
                subtitle: Text(_getThemeModeLabel(Pref.themeMode)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeModeDialog(context),
              ),
              // 动态取色
              SwitchListTile(
                secondary: const Icon(Icons.palette_outlined),
                title: const Text('动态取色'),
                subtitle: const Text('跟随系统壁纸颜色'),
                value: Pref.dynamicColor,
                onChanged: (value) {
                  Pref.dynamicColor = value;
                  Get.forceAppUpdate();
                },
              ),
              // 主题色
              ListTile(
                leading: const Icon(Icons.color_lens_outlined),
                title: const Text('主题色'),
                subtitle: Text(themeColorTypes[Pref.customColor].label),
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: themeColorTypes[Pref.customColor].color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                enabled: !Pref.dynamicColor,
                onTap: () => _showColorPickerDialog(context),
              ),

            ],
          ),
          // 交互设置
          _buildSection(
            title: '交互',
            children: [
              // 滑动振动反馈
              SwitchListTile(
                secondary: const Icon(Icons.vibration_rounded),
                title: const Text('滑动振动反馈'),
                subtitle: const Text('左滑右滑切换内容时触发振动'),
                value: Pref.enableSwipeHaptics,
                onChanged: (value) {
                  Pref.enableSwipeHaptics = value;
                  Get.forceAppUpdate();
                },
              ),
            ],
          ),
          // 关于
          _buildSection(
            title: '关于',
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('关于 Tritium'),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Tritium',
                    applicationVersion: '0.1.0',
                    applicationLegalese: '知乎第三方客户端',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  String _getThemeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
    }
  }

  void _showThemeModeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('主题模式'),
        children: ThemeMode.values.map((mode) {
          return RadioListTile<ThemeMode>(
            title: Text(_getThemeModeLabel(mode)),
            value: mode,
            groupValue: Pref.themeMode,
            onChanged: (value) {
              if (value != null) {
                Pref.themeMode = value;
                Get.changeThemeMode(value);
                Get.forceAppUpdate();
              }
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showColorPickerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择主题色'),
        children: [
          SizedBox(
            width: 300,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: themeColorTypes.asMap().entries.map((entry) {
                final index = entry.key;
                final type = entry.value;
                final isSelected = Pref.customColor == index;
                
                return GestureDetector(
                  onTap: () {
                    Pref.customColor = index;
                    Get.forceAppUpdate();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: type.color,
                      borderRadius: BorderRadius.circular(24),
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [BoxShadow(color: type.color.withValues(alpha: 0.5), blurRadius: 8)]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  String _getCommentSortLabel(String sort) {
    switch (sort) {
      case 'score': return '按热度 (默认)';
      case 'ts': return '按时间';
      default: return '按热度';
    }
  }

  void _showHomeTabDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('默认启动页'),
        children: [
          RadioListTile<int>(
            title: const Text('推荐'),
            value: 0,
            groupValue: Pref.defaultHomeTab,
            onChanged: (value) {
              if (value != null) {
                Pref.defaultHomeTab = value;
                Get.forceAppUpdate();
              }
              Navigator.pop(context);
            },
          ),
          RadioListTile<int>(
            title: const Text('热榜'),
            value: 1,
            groupValue: Pref.defaultHomeTab,
            onChanged: (value) {
              if (value != null) {
                Pref.defaultHomeTab = value;
                Get.forceAppUpdate();
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showAnswerSortDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('默认回答排序'),
        children: [
          RadioListTile<String>(
            title: const Text('按热度 (默认)'),
            value: 'default',
            groupValue: Pref.defaultAnswerSort,
            onChanged: (value) {
              if (value != null) {
                Pref.defaultAnswerSort = value;
                Get.forceAppUpdate();
              }
              Navigator.pop(context);
            },
          ),
          RadioListTile<String>(
            title: const Text('按时间 (最新)'),
            value: 'created',
            groupValue: Pref.defaultAnswerSort,
            onChanged: (value) {
              if (value != null) {
                Pref.defaultAnswerSort = value;
                Get.forceAppUpdate();
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showCommentSortDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('默认评论排序'),
        children: [
          RadioListTile<String>(
            title: const Text('按热度'),
            value: 'score',
            groupValue: Pref.defaultCommentSort,
            onChanged: (value) {
              if (value != null) {
                Pref.defaultCommentSort = value;
                Get.forceAppUpdate();
              }
              Navigator.pop(context);
            },
          ),
          RadioListTile<String>(
            title: const Text('按时间'),
            value: 'ts',
            groupValue: Pref.defaultCommentSort,
            onChanged: (value) {
              if (value != null) {
                Pref.defaultCommentSort = value;
                Get.forceAppUpdate();
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
