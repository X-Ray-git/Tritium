import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'common/constants/constants.dart';
import 'common/theme/theme_utils.dart';
import 'common/theme/theme_color_type.dart';
import 'common/widgets/loading_widget.dart';
import 'router/app_pages.dart';
import 'services/account_service.dart';
import 'utils/storage.dart';
import 'http/init.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化存储
  await GStorage.init();

  // 初始化网络请求
  Request();
  Request.setCookie();

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
        targetMode = modes.firstWhereOrNull((m) => m.toString() == savedModeStr);
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

class TritiumApp extends StatefulWidget {
  const TritiumApp({super.key});

  @override
  State<TritiumApp> createState() => _TritiumAppState();
}

class _TritiumAppState extends State<TritiumApp> {
  ColorScheme? _lightDynamic;
  ColorScheme? _darkDynamic;

  @override
  void initState() {
    super.initState();
    _initDynamicColor();
  }

  Future<void> _initDynamicColor() async {
    if (!Pref.dynamicColor) return;
    
    try {
      final corePalette = await DynamicColorPlugin.getCorePalette();
      if (corePalette != null) {
        setState(() {
          _lightDynamic = corePalette.toColorScheme();
          _darkDynamic = corePalette.toColorScheme(brightness: Brightness.dark);
        });
        return;
      }

      final accentColor = await DynamicColorPlugin.getAccentColor();
      if (accentColor != null) {
        setState(() {
          _lightDynamic = ThemeUtils.colorSchemeFromSeed(
            seedColor: accentColor,
            brightness: Brightness.light,
          );
          _darkDynamic = ThemeUtils.colorSchemeFromSeed(
            seedColor: accentColor,
            brightness: Brightness.dark,
          );
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // 判断是否使用动态取色
    final useDynamicColor = Pref.dynamicColor && 
        _lightDynamic != null && 
        _darkDynamic != null;

    // 获取主题颜色
    final brandColor = themeColorTypes[Pref.customColor].color;

    // 生成 ColorScheme
    final lightColorScheme = useDynamicColor
        ? _lightDynamic!
        : ThemeUtils.colorSchemeFromSeed(
            seedColor: brandColor,
            brightness: Brightness.light,
          );

    final darkColorScheme = useDynamicColor
        ? _darkDynamic!
        : ThemeUtils.colorSchemeFromSeed(
            seedColor: brandColor,
            brightness: Brightness.dark,
          );

    return GetMaterialApp(
      title: Constants.appName,
      debugShowCheckedModeBanner: false,
      
      // 主题配置
      theme: ThemeUtils.getThemeData(
        colorScheme: lightColorScheme,
        isDynamic: useDynamicColor,
      ),
      darkTheme: ThemeUtils.getThemeData(
        colorScheme: darkColorScheme,
        isDark: true,
        isDynamic: useDynamicColor,
      ),
      themeMode: Pref.themeMode,

      // 本地化
      localizationsDelegates: const [
        GlobalCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      locale: const Locale('zh', 'CN'),
      fallbackLocale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],

      // 路由配置
      initialRoute: Routes.main,
      getPages: appPages,
      defaultTransition: Transition.native,

      // SmartDialog 配置
      builder: FlutterSmartDialog.init(
        toastBuilder: (String msg) => _CustomToast(msg: msg),
        loadingBuilder: (msg) => LoadingWidget(msg: msg),
      ),
      navigatorObservers: [FlutterSmartDialog.observer],
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
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        msg,
        style: TextStyle(
          color: colorScheme.onInverseSurface,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
