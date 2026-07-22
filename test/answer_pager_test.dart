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
}
