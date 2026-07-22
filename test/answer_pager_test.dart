import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tritium/http/content_http.dart';
import 'package:tritium/pages/answer/answer_page.dart';
import 'package:tritium/utils/storage.dart';

void main() {
  late Directory storageDirectory;

  setUpAll(() async {
    storageDirectory = await Directory.systemTemp.createTemp(
      'tritium-answer-pager-test-',
    );
    await GStorage.init(pathOverride: storageDirectory.path);
  });

  setUp(() {
    Get.testMode = true;
    AnswerHttp.cache
      ..clear()
      ..addAll({
        'a': {
          'question': {'id': 'q', 'title': '测试问题'},
          'content': '<p>第一页正文</p>${List.filled(40, '<p>第一页填充内容</p>').join()}',
          'voteup_count': 11,
          'comment_count': 12,
          'author': {'name': '甲'},
        },
        'b': {
          'question': {'id': 'q', 'title': '测试问题'},
          'content': '<p>第二页正文</p>${List.filled(40, '<p>第二页填充内容</p>').join()}',
          'voteup_count': 21,
          'comment_count': 22,
          'author': {'name': '乙'},
        },
      });
  });

  tearDown(() {
    AnswerHttp.cache.clear();
    Get.reset();
  });

  tearDownAll(() async {
    await GStorage.close();
    await storageDirectory.delete(recursive: true);
  });

  testWidgets('horizontal page switch settles on adjacent cached answer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const GetMaterialApp(
        home: AnswerPage(questionId: 'q', answerId: 'a', answerIds: ['a', 'b']),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第一页正文'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();

    expect(find.text('第二页正文'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsed title follows the source title geometry', (
    tester,
  ) async {
    const longTitle = '这是一个用于验证多行标题完全滚出以后顶部标题才出现的测试问题标题';
    AnswerHttp.cache['a']!['question'] = {'id': 'q', 'title': longTitle};

    await tester.pumpWidget(
      const GetMaterialApp(
        home: AnswerPage(questionId: 'q', answerId: 'a', answerIds: ['a', 'b']),
      ),
    );
    await tester.pumpAndSettle();

    Finder sourceTitle() => find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data == longTitle &&
          widget.style?.fontSize == 20,
    );
    AnimatedOpacity collapsedTitle() => tester.widget<AnimatedOpacity>(
      find.byKey(const Key('answer-collapsed-title')),
    );
    double appBarBottom() =>
        MediaQuery.paddingOf(tester.element(find.byType(AnswerPage))).top + 48;

    expect(sourceTitle(), findsOneWidget);
    expect(tester.getBottomLeft(sourceTitle()).dy, greaterThan(appBarBottom()));
    expect(collapsedTitle().opacity, 0);
    final fixedAppBarRect = tester.getRect(find.byType(AppBar));

    await tester.drag(
      find.byKey(const Key('answer-scroll-a')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(sourceTitle(), findsNothing);
    expect(collapsedTitle().opacity, 1);
    expect(tester.getRect(find.byType(AppBar)), fixedAppBarRect);

    // 深度阅读后只反向少量时，正文尚未回到顶部，原始标题不得提前展开。
    await tester.drag(
      find.byKey(const Key('answer-scroll-a')),
      const Offset(0, 40),
    );
    await tester.pumpAndSettle();
    if (sourceTitle().evaluate().isNotEmpty) {
      expect(
        tester.getBottomLeft(sourceTitle()).dy,
        lessThanOrEqualTo(appBarBottom()),
      );
    }
    expect(collapsedTitle().opacity, 1);
    expect(tester.getRect(find.byType(AppBar)), fixedAppBarRect);

    await tester.drag(
      find.byKey(const Key('answer-scroll-a')),
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();
    expect(sourceTitle(), findsOneWidget);
    expect(tester.getBottomLeft(sourceTitle()).dy, greaterThan(appBarBottom()));
    expect(collapsedTitle().opacity, 0);
    expect(tester.getRect(find.byType(AppBar)), fixedAppBarRect);
  });
}
