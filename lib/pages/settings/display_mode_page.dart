import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../utils/storage.dart';
import '../../common/constants/constants.dart';

/// 屏幕帧率设置页面
class DisplayModePage extends StatefulWidget {
  const DisplayModePage({super.key});

  @override
  State<DisplayModePage> createState() => _DisplayModePageState();
}

class _DisplayModePageState extends State<DisplayModePage> {
  List<DisplayMode> modes = <DisplayMode>[];
  DisplayMode? active;
  DisplayMode? preferred;

  Box setting = GStorage.setting;

  @override
  void initState() {
    super.initState();
    init();
  }

  /// 获取所有的 mode
  Future<void> fetchAll() async {
    preferred = await FlutterDisplayMode.preferred;
    active = await FlutterDisplayMode.active;
    setting.put(StorageKeys.displayMode, preferred.toString());
    if (mounted) {
      setState(() {});
    }
  }

  /// 初始化 mode / 手动设置
  Future<void> init() async {
    try {
      modes = await FlutterDisplayMode.supported;
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint(e.toString());
    }

    final value = setting.get(StorageKeys.displayMode);
    if (value != null) {
      preferred = modes.firstWhere(
        (e) => e.toString() == value,
        orElse: () => DisplayMode.auto,
      );
    }

    preferred ??= DisplayMode.auto;

    FlutterDisplayMode.setPreferredMode(preferred!).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 100), fetchAll);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('屏幕帧率设置')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              '选择更高的刷新率可以获得更流畅的滚动体验。\n如果没有生效，请尝试重启应用。',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: ListView.builder(
              itemCount: modes.length,
              itemBuilder: (context, index) {
                final DisplayMode mode = modes[index];
                final isSelected = mode == preferred;
                final isActive = mode == active;

                String title;
                if (mode == DisplayMode.auto) {
                  title = '自动';
                } else {
                  title = '${mode.width}x${mode.height} @ ${mode.refreshRate.toStringAsFixed(0)}Hz';
                }

                return RadioListTile<DisplayMode>(
                  value: mode,
                  groupValue: preferred,
                  title: Row(
                    children: [
                      Expanded(child: Text(title)),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '当前',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  selected: isSelected,
                  onChanged: (DisplayMode? newMode) {
                    if (newMode != null) {
                      FlutterDisplayMode.setPreferredMode(newMode).whenComplete(
                        () => Future.delayed(
                          const Duration(milliseconds: 100),
                          fetchAll,
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
