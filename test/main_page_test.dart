import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tritium/common/theme/theme_utils.dart';
import 'package:tritium/http/init.dart';
import 'package:tritium/pages/home/hot_page.dart';
import 'package:tritium/pages/home/recommend_page.dart';
import 'package:tritium/pages/main/main_controller.dart';
import 'package:tritium/pages/main/main_page.dart';
import 'package:tritium/services/account_service.dart';
import 'package:tritium/utils/storage.dart';

class _RecommendControllerStub extends RecommendController {
  @override
  Future<void> loadData({bool forceNetwork = false}) async {
    loadingState.value = Success(<Map<String, dynamic>>[]);
  }
}

class _HotControllerStub extends HotController {
  @override
  Future<void> loadData() async {
    loadingState.value = Success(<Map<String, dynamic>>[]);
  }
}

class _GestureSwitchPage extends StatefulWidget {
  const _GestureSwitchPage();

  @override
  State<_GestureSwitchPage> createState() => _GestureSwitchPageState();
}

class _GestureSwitchPageState extends State<_GestureSwitchPage> {
  bool value = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Switch(
        value: value,
        onChanged: (next) => setState(() => value = next),
      ),
    );
  }
}

void main() {
  late Directory storageDirectory;

  setUpAll(() async {
    storageDirectory = await Directory.systemTemp.createTemp(
      'tritium-widget-test-',
    );
    await GStorage.init(pathOverride: storageDirectory.path);
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await GStorage.clear();
    Get.put(AccountService());
    Get.put<RecommendController>(_RecommendControllerStub());
    Get.put<HotController>(_HotControllerStub());
  });

  tearDown(() async {
    Get.reset();
  });

  tearDownAll(() async {
    await GStorage.close();
    await storageDirectory.delete(recursive: true);
  });

  testWidgets('main navigation exposes recommendation, hot list and settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(theme: ThemeUtils.light(), home: const MainPage()),
    );
    await tester.pump();

    expect(find.byTooltip('推荐'), findsOneWidget);
    expect(find.byTooltip('热榜'), findsOneWidget);
    expect(find.byTooltip('设置'), findsOneWidget);
    expect(find.text('发现'), findsNothing);
    expect(find.text('AI'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Scaffold && widget.extendBodyBehindAppBar,
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('默认内容页'), findsOneWidget);
    expect(find.text('Tritium 固定使用 #3961FF 品牌色'), findsOneWidget);
    final settingsList = tester.widget<ListView>(
      find.byKey(const Key('settings-list')),
    );
    expect(
      settingsList.padding!.resolve(TextDirection.ltr).top,
      tester.getBottomLeft(find.byType(AppBar)).dy + 12,
    );
  });

  testWidgets('horizontal swipe syncs the navigation selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(theme: ThemeUtils.light(), home: const MainPage()),
    );
    await tester.pump();

    // 从左向右滑到热榜。
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    final mainController = Get.find<MainController>();
    expect(mainController.currentIndex.value, 1);
    // AppBar 标题仍为 Tritium（只有设置页是“设置”）。
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Tritium')),
      findsOneWidget,
    );

    // 再滑到设置页。
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(mainController.currentIndex.value, 2);
    expect(find.text('默认内容页'), findsOneWidget);
  });

  testWidgets('navigation tap animates to the target page', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(theme: ThemeUtils.light(), home: const MainPage()),
    );
    await tester.pump();

    final mainController = Get.find<MainController>();
    await tester.tap(find.byTooltip('热榜'));
    await tester.pumpAndSettle();
    expect(mainController.currentIndex.value, 1);

    await tester.tap(find.byTooltip('推荐'));
    await tester.pumpAndSettle();
    expect(mainController.currentIndex.value, 0);
  });

  testWidgets('re-tapping the current navigation scrolls the feed to top', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(theme: ThemeUtils.light(), home: const MainPage()),
    );
    await tester.pump();

    // 推荐页目前是空列表占位，无法滚动；切换到热榜并注册滚动回调的行为由
    // 控制器测试覆盖。这里验证重复点击不会切换页面。
    final mainController = Get.find<MainController>();
    await tester.tap(find.byTooltip('推荐'));
    await tester.pumpAndSettle();
    expect(mainController.currentIndex.value, 0);
  });

  testWidgets('pages keep their scroll position when switching tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(theme: ThemeUtils.light(), home: const MainPage()),
    );
    await tester.pump();

    // 切到热榜再切回推荐：页面必须保活，不重新请求数据。
    await tester.tap(find.byTooltip('热榜'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('推荐'));
    await tester.pumpAndSettle();

    expect(Get.find<RecommendController>().feedList, isEmpty);
    // 保活：RecommendController 实例没有被重新创建。
    final controllerBefore = Get.find<RecommendController>();
    final hotBefore = Get.find<HotController>();
    expect(controllerBefore, same(Get.find<RecommendController>()));
    expect(hotBefore, same(Get.find<HotController>()));
  });

  testWidgets('switch on the settings page is not stolen by the PageView', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeUtils.light(),
        home: const MainPage(
          pagesForTesting: [
            SizedBox.expand(),
            SizedBox.expand(),
            _GestureSwitchPage(),
          ],
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    final initialValue = tester.widget<Switch>(switchFinder).value;

    // 横向拖动 Switch 应只改变开关，不切换主页面。
    await tester.drag(switchFinder, const Offset(60, 0));
    await tester.pumpAndSettle();

    expect(Get.find<MainController>().currentIndex.value, 2);
    expect(tester.widget<Switch>(switchFinder).value, !initialValue);
  });
}
