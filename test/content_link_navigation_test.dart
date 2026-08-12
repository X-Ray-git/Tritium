import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tritium/common/widgets/html/custom_html.dart';
import 'package:tritium/http/content_http.dart';
import 'package:tritium/router/app_pages.dart';
import 'package:tritium/services/content_link_service.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
    ContentLinkService.resetNavigationStateForTesting();
    AnswerHttp.cache['200'] = <String, dynamic>{};
  });

  tearDown(() {
    AnswerHttp.cache.remove('200');
    ContentLinkService.resetNavigationStateForTesting();
    Get.reset();
  });

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

  testWidgets('an answer link can open another answer route', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.answer,
        getPages: [
          GetPage(
            name: Routes.answer,
            page: () {
              final arguments = Get.arguments as Map<String, dynamic>?;
              return Scaffold(
                body: Text('answer:${arguments?['answerId'] ?? 'initial'}'),
              );
            },
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('answer:initial'), findsOneWidget);

    unawaited(
      ContentLinkService.open('https://www.zhihu.com/question/100/answer/200'),
    );
    await tester.pumpAndSettle();

    expect(find.text('answer:200'), findsOneWidget);
    expect(Get.currentRoute, Routes.answer);
  });

  testWidgets('a selectable answer link reaches same-type navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.answer,
        getPages: [
          GetPage(
            name: Routes.answer,
            page: () {
              final arguments = Get.arguments as Map<String, dynamic>?;
              final answerId = arguments?['answerId']?.toString();
              if (answerId != null) {
                return Scaffold(body: Text('answer:$answerId'));
              }
              return const Scaffold(
                body: SelectionArea(
                  child: CustomHtml(
                    content:
                        '<p><a href="https://www.zhihu.com/question/100/'
                        'answer/200">另一个回答</a></p>',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('另一个回答', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.text('answer:200'), findsOneWidget);
    expect(Get.currentRoute, Routes.answer);
  });

  for (final testCase in [
    (
      label: 'article',
      route: Routes.article,
      argument: 'articleId',
      url: 'https://zhuanlan.zhihu.com/p/123',
      expectedId: '123',
    ),
    (
      label: 'pin',
      route: Routes.pin,
      argument: 'pinId',
      url: 'https://www.zhihu.com/pin/456',
      expectedId: '456',
    ),
    (
      label: 'user',
      route: Routes.user,
      argument: 'userId',
      url: 'https://www.zhihu.com/people/test-user',
      expectedId: 'test-user',
    ),
  ]) {
    final article = testCase.label == 'article' ? 'an' : 'a';
    testWidgets(
      '$article ${testCase.label} link can open the same route type',
      (tester) async {
        await tester.pumpWidget(
          GetMaterialApp(
            initialRoute: testCase.route,
            getPages: [
              GetPage(
                name: testCase.route,
                page: () {
                  final arguments = Get.arguments as Map<String, dynamic>?;
                  return Scaffold(
                    body: Text(
                      '${testCase.label}:'
                      '${arguments?[testCase.argument] ?? 'initial'}',
                    ),
                  );
                },
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('${testCase.label}:initial'), findsOneWidget);

        unawaited(ContentLinkService.open(testCase.url));
        await tester.pumpAndSettle();

        expect(
          find.text('${testCase.label}:${testCase.expectedId}'),
          findsOneWidget,
        );
        expect(Get.currentRoute, testCase.route);
      },
    );
  }

  testWidgets('duplicate callbacks push a concrete target only once', (
    tester,
  ) async {
    final createdIds = <String>[];
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.question,
        getPages: [
          GetPage(
            name: Routes.question,
            page: () {
              final arguments = Get.arguments as Map<String, dynamic>?;
              final id = arguments?['questionId']?.toString() ?? 'initial';
              createdIds.add(id);
              return Scaffold(body: Text('question:$id'));
            },
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    const url = 'https://www.zhihu.com/question/631983014';
    unawaited(ContentLinkService.open(url));
    unawaited(ContentLinkService.open(url));
    await tester.pumpAndSettle();

    expect(find.text('question:631983014'), findsOneWidget);
    expect(createdIds.where((id) => id == '631983014'), hasLength(1));

    // Coalescing is scoped to one physical tap, not the lifetime of the route.
    await tester.pump(const Duration(milliseconds: 600));
    unawaited(ContentLinkService.open(url));
    await tester.pumpAndSettle();

    expect(createdIds.where((id) => id == '631983014'), hasLength(2));
  });
}
