import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'common/constants/constants.dart';
import 'common/theme/theme_utils.dart';
import 'common/widgets/loading_widget.dart';
import 'router/app_pages.dart';
import 'services/account_service.dart';
import 'services/app_version_service.dart';
import 'utils/storage.dart';
import 'http/init.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化存储
  await GStorage.init();
  await AppVersionService.init();

  // 初始化网络请求
  Request();

  // 注册服务
  Get.put(AccountService());

  // 设置状态栏样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // 设置沉浸式状态栏
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // 设置高帧率（Android）
  if (Platform.isAndroid) {
    try {
      final modes = await FlutterDisplayMode.supported;

      // 从存储中获取设置
      final savedModeStr = GStorage.setting.get(StorageKeys.displayMode);
      DisplayMode? targetMode;

      if (savedModeStr != null) {
        // 尝试匹配保存的模式
        targetMode = modes.firstWhereOrNull(
          (m) => m.toString() == savedModeStr,
        );
      }

      // 如果没有保存的设置，默认使用最高刷新率
      if (targetMode == null) {
        DisplayMode? maxMode;
        for (final mode in modes) {
          if (maxMode == null || mode.refreshRate > maxMode.refreshRate) {
            maxMode = mode;
          }
        }
        targetMode = maxMode;
      }

      if (targetMode != null) {
        await FlutterDisplayMode.setPreferredMode(targetMode);
      } else {
        await FlutterDisplayMode.setHighRefreshRate();
      }
    } catch (e) {
      debugPrint('Error setting high refresh rate: $e');
    }
  }

  runApp(const TritiumApp());
}

class TritiumApp extends StatelessWidget {
  const TritiumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box>(
      valueListenable: GStorage.setting.listenable(
        keys: const [StorageKeys.themeMode],
      ),
      builder: (context, _, _) => GetMaterialApp(
        title: Constants.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeUtils.light(),
        darkTheme: ThemeUtils.dark(),
        themeMode: Pref.themeMode,

        localizationsDelegates: const [
          GlobalCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        locale: const Locale('zh', 'CN'),
        fallbackLocale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],

        initialRoute: Routes.main,
        getPages: appPages,
        defaultTransition: Transition.native,

        builder: FlutterSmartDialog.init(
          toastBuilder: (String msg) => _CustomToast(msg: msg),
          loadingBuilder: (msg) => LoadingWidget(msg: msg),
        ),
        navigatorObservers: [FlutterSmartDialog.observer],
      ),
    );
  }
}

/// 自定义 Toast
class _CustomToast extends StatelessWidget {
  final String msg;

  const _CustomToast({required this.msg});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 48),
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            width: 0.5,
          ),
        ),
        child: Text(
          msg,
          style: TextStyle(
            color: colorScheme.onInverseSurface,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
