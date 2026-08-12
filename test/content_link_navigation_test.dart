import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tritium/router/app_pages.dart';
import 'package:tritium/services/content_link_service.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  tearDown(Get.reset);

  testWidgets('a question link can open another question route', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.question,
        getPages: [
          GetPage(
            name: Routes.question,
            page: () {
              final arguments = Get.arguments as Map<String, dynamic>?;
              return Scaffold(
                body: Text('question:${arguments?['questionId'] ?? 'initial'}'),
              );
            },
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('question:initial'), findsOneWidget);

    // 不等待返回值：ContentLinkService.open 会等待新页面被弹出。
    unawaited(
      ContentLinkService.open('https://www.zhihu.com/question/631983014'),
    );
    await tester.pumpAndSettle();

    expect(find.text('question:631983014'), findsOneWidget);
    expect(Get.currentRoute, Routes.question);
  });
}
