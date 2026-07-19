import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tritium/common/theme/theme_utils.dart';
import 'package:tritium/pages/home/hot_page.dart';
import 'package:tritium/pages/home/recommend_page.dart';
import 'package:tritium/pages/main/main_page.dart';
import 'package:tritium/services/account_service.dart';
import 'package:tritium/utils/storage.dart';

class _RecommendControllerStub extends RecommendController {
  @override
  Future<void> loadData({bool forceNetwork = false}) async {}
}

class _HotControllerStub extends HotController {
  @override
  Future<void> loadData() async {}
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

  testWidgets('main navigation only exposes content and settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(theme: ThemeUtils.light(), home: const MainPage()),
    );
    await tester.pump();

    expect(find.byTooltip('内容'), findsOneWidget);
    expect(find.byTooltip('设置'), findsOneWidget);
    expect(find.text('发现'), findsNothing);
    expect(find.text('AI'), findsNothing);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('默认内容页'), findsOneWidget);
    expect(find.text('Tritium 固定使用 #3961FF 品牌色'), findsOneWidget);
  });
}
