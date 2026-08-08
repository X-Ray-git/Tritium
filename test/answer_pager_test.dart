import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tritium/http/content_http.dart';
import 'package:tritium/http/init.dart';
import 'package:tritium/pages/answer/answer_page.dart';
import 'package:tritium/pages/answer/answer_pager.dart';
import 'package:tritium/services/reading_history_service.dart';
import 'package:tritium/utils/storage.dart';

/// 立即失败的假 HttpClient：让未缓存内容的加载快速进入失败态，避免真实
/// 网络请求与挂起计时器。
class _FailingHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FailingHttpClient();
  }
}

class _FailingHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Map<String, dynamic> _page(
  List<String> ids, {
  String? nextUrl,
  bool isEnd = false,
}) {
  return {
    'data': ids
        .map(
          (id) => {
            'target': {'id': id},
          },
        )
        .toList(),
    'paging': {'next': ?nextUrl, 'is_end': isEnd},
  };
}

/// 可编排的假加载器：按调用顺序返回页面。
class _FakeLoader {
  final responses = <Map<String, dynamic>>[];
  final failures = <String?>[];
  final requests = <String?>[];
  var calls = 0;

  Future<LoadingState<Map<String, dynamic>>> call({
    required String questionId,
    required String sortBy,
    String? nextUrl,
  }) async {
    calls++;
    requests.add(nextUrl);
    if (calls <= failures.length && failures[calls - 1] == nextUrl) {
      return const Error('网络错误');
    }
    if (responses.isNotEmpty) {
      return Success(responses.removeAt(0));
    }
    return const Error('没有更多页面');
  }
}

void main() {
  late Directory storageDirectory;

  setUpAll(() async {
    storageDirectory = await Directory.systemTemp.createTemp(
      'tritium-answer-pager-test-',
    );
    await GStorage.init(pathOverride: storageDirectory.path);
    ReadingHistoryService.persistenceEnabled = false;
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
    ReadingHistoryService.persistenceEnabled = true;
    await GStorage.close();
    await storageDirectory.delete(recursive: true);
  });

  group('widget', () {
    testWidgets('horizontal page switch settles on adjacent cached answer', (
      tester,
    ) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: AnswerPage(
            questionId: 'q',
            answerId: 'a',
            answerIds: ['a', 'b'],
          ),
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
          home: AnswerPage(
            questionId: 'q',
            answerId: 'a',
            answerIds: ['a', 'b'],
          ),
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
          MediaQuery.paddingOf(tester.element(find.byType(AnswerPage))).top +
          48;

      expect(sourceTitle(), findsOneWidget);
      expect(
        tester.getBottomLeft(sourceTitle()).dy,
        greaterThan(appBarBottom()),
      );
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
      expect(
        tester.getBottomLeft(sourceTitle()).dy,
        greaterThan(appBarBottom()),
      );
      expect(collapsedTitle().opacity, 0);
      expect(tester.getRect(find.byType(AppBar)), fixedAppBarRect);
    });

    testWidgets('bottom bar shows a dash before the answer is loaded', (
      tester,
    ) async {
      // 清空缓存：底栏统计必须在正文加载前保持“未加载”状态，而不是显示 0。
      AnswerHttp.cache.clear();
      HttpOverrides.global = _FailingHttpOverrides();

      await tester.pumpWidget(
        const GetMaterialApp(
          home: AnswerPage(
            questionId: 'q',
            answerId: 'not-cached',
            answerIds: ['not-cached'],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 正文尚未加载完成：点赞/评论显示 “—”，而不是 0。
      expect(find.text('—'), findsWidgets);
      expect(find.text('0'), findsNothing);

      HttpOverrides.global = null;
    });
  });

  group('AnswerPager', () {
    test('continues loading next pages from a seeded cursor', () async {
      final loader = _FakeLoader();
      final pager = AnswerPager(
        questionId: 'q',
        answerIds: const ['a', 'b'],
        sortBy: 'default',
        loader: loader.call,
        nextUrl: 'cursor-1',
      );
      loader.responses.add(_page(['c', 'd'], nextUrl: 'cursor-2'));
      loader.responses.add(_page(['e'], isEnd: true));

      expect(pager.hasMore, isTrue);
      await pager.loadNextPage();
      expect(pager.answerIds, ['a', 'b', 'c', 'd']);
      expect(pager.nextUrl, 'cursor-2');
      expect(pager.isEnd, isFalse);

      await pager.loadNextPage();
      expect(pager.answerIds, ['a', 'b', 'c', 'd', 'e']);
      expect(pager.isEnd, isTrue);
      expect(pager.hasMore, isFalse);

      // is_end 后不再发起请求。
      final callsBefore = loader.calls;
      await pager.loadNextPage();
      expect(loader.calls, callsBefore);
    });

    test(
      'single answer entry fills the first page and keeps the current one',
      () async {
        final loader = _FakeLoader();
        final pager = AnswerPager(
          questionId: 'q',
          answerIds: const ['x'],
          sortBy: 'created',
          loader: loader.call,
        );
        loader.responses.add(_page(['a', 'b'], nextUrl: 'cursor-1'));
        loader.responses.add(_page(['c'], isEnd: true));

        expect(pager.needsFirstPageLoad, isTrue);
        await pager.loadFirstPage('x');
        // 当前回答不在第一页时插到最前。
        expect(pager.answerIds, ['x', 'a', 'b']);
        expect(pager.nextUrl, 'cursor-1');

        await pager.loadNextPage();
        expect(pager.answerIds, ['x', 'a', 'b', 'c']);
      },
    );

    test(
      'keeps the current answer first when it is in the fetched page',
      () async {
        final loader = _FakeLoader();
        final pager = AnswerPager(
          questionId: 'q',
          answerIds: const ['x'],
          sortBy: 'default',
          loader: loader.call,
        );
        loader.responses.add(_page(['a', 'x', 'b'], nextUrl: 'cursor-1'));

        await pager.loadFirstPage('x');

        expect(pager.answerIds, ['x', 'a', 'b']);
        expect(pager.nextUrl, 'cursor-1');
      },
    );

    test('deduplicates answer ids across pages', () async {
      final loader = _FakeLoader();
      final pager = AnswerPager(
        questionId: 'q',
        answerIds: const ['a', 'b', 'a', ''],
        sortBy: 'default',
        loader: loader.call,
        nextUrl: 'cursor-1',
      );
      expect(pager.answerIds, ['a', 'b']);
      loader.responses.add(_page(['b', 'c', 'a'], isEnd: true));

      await pager.loadNextPage();
      expect(pager.answerIds, ['a', 'b', 'c']);
    });

    test('a duplicate-only page stops pagination as no progress', () async {
      final loader = _FakeLoader();
      final pager = AnswerPager(
        questionId: 'q',
        answerIds: const ['a', 'b'],
        sortBy: 'default',
        loader: loader.call,
        nextUrl: 'cursor-1',
      );
      loader.responses.add(_page(['a', 'b'], nextUrl: 'cursor-2'));

      await pager.loadNextPage();

      expect(pager.answerIds, ['a', 'b']);
      expect(pager.nextUrl, isNull);
      expect(pager.hasMore, isFalse);
    });

    test('repeated cursors and empty pages stop automatic requests', () async {
      final loader = _FakeLoader();
      final pager = AnswerPager(
        questionId: 'q',
        answerIds: const ['a'],
        sortBy: 'default',
        loader: loader.call,
        nextUrl: 'cursor-1',
      );
      loader.responses.add(_page([], nextUrl: 'cursor-1'));

      await pager.loadNextPage();
      // 空页 + 重复 cursor -> 停止。
      expect(pager.nextUrl, isNull);
      expect(pager.hasMore, isFalse);

      final callsBefore = loader.calls;
      await pager.loadNextPage();
      expect(loader.calls, callsBefore);
    });

    test('a failed page keeps a retryable error state', () async {
      final loader = _FakeLoader();
      final pager = AnswerPager(
        questionId: 'q',
        answerIds: const ['a'],
        sortBy: 'default',
        loader: loader.call,
        nextUrl: 'cursor-1',
      );
      loader.failures.add('cursor-1');
      loader.responses.add(_page(['b'], isEnd: true));

      await pager.loadNextPage();
      expect(pager.hasError, isTrue);
      expect(pager.answerIds, ['a']);
      // nextUrl 保留，点击重试可以恢复。
      expect(pager.nextUrl, 'cursor-1');

      pager.clearError();
      await pager.loadNextPage();
      expect(pager.hasError, isFalse);
      expect(pager.answerIds, ['a', 'b']);
    });

    test('first page failure can retry the first page', () async {
      final loader = _FakeLoader();
      final pager = AnswerPager(
        questionId: 'q',
        answerIds: const ['x'],
        sortBy: 'default',
        loader: loader.call,
      );
      loader.failures.add(null);
      loader.responses.add(_page(['a', 'b'], nextUrl: 'cursor-1'));

      await pager.loadFirstPage('x');
      expect(pager.hasError, isTrue);
      expect(pager.answerIds, ['x']);

      await pager.retry('x');
      expect(pager.hasError, isFalse);
      expect(pager.answerIds, ['x', 'a', 'b']);
    });

    test('sort order is preserved across pages', () async {
      final loader = _FakeLoader();
      final pager = AnswerPager(
        questionId: 'q',
        answerIds: const ['a'],
        sortBy: 'created',
        loader: loader.call,
        nextUrl: 'cursor-1',
      );
      loader.responses.add(_page(['b'], isEnd: true));

      await pager.loadNextPage();
      expect(loader.requests.first, 'cursor-1');
      expect(pager.sortBy, 'created');
    });

    test('prefetch threshold is within two items of the tail', () async {
      final loader = _FakeLoader();
      final pager = AnswerPager(
        questionId: 'q',
        answerIds: const ['a', 'b', 'c', 'd', 'e'],
        sortBy: 'default',
        loader: loader.call,
        nextUrl: 'cursor-1',
      );

      expect(pager.shouldPrefetch(0), isFalse);
      expect(pager.shouldPrefetch(1), isFalse);
      expect(pager.shouldPrefetch(2), isFalse);
      expect(pager.shouldPrefetch(3), isTrue);
      expect(pager.shouldPrefetch(4), isTrue);
      // 占位页/越界索引不需要预取。
      expect(pager.shouldPrefetch(5), isFalse);
      expect(pager.shouldPrefetch(-1), isFalse);
    });

    test('needsFirstPageLoad is false for a full seed with cursor', () {
      final loader = _FakeLoader();
      final pager = AnswerPager(
        questionId: 'q',
        answerIds: const ['a', 'b'],
        sortBy: 'default',
        loader: loader.call,
        nextUrl: 'cursor-1',
      );
      expect(pager.needsFirstPageLoad, isFalse);
    });
  });
}
