import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/common/widgets/inline_comment_widget.dart';
import 'package:tritium/http/init.dart';
import 'package:tritium/utils/comment_auto_load.dart';
import 'package:tritium/utils/storage.dart';

void main() {
  late Directory storageDirectory;

  setUpAll(() async {
    storageDirectory = await Directory.systemTemp.createTemp(
      'tritium-comment-auto-load-test-',
    );
    await GStorage.init(pathOverride: storageDirectory.path);
  });

  setUp(GStorage.clear);

  tearDownAll(() async {
    await GStorage.close();
    await storageDirectory.delete(recursive: true);
  });

  test('triggers when a long page scrolls near the sentinel', () {
    expect(
      shouldAutoLoadMore(
        sentinelScrollOffset: 5000,
        scrollOffset: 3000,
        viewportDimension: 700,
      ),
      isFalse,
    );
    expect(
      shouldAutoLoadMore(
        sentinelScrollOffset: 5000,
        scrollOffset: 3600,
        viewportDimension: 700,
      ),
      isTrue,
    );
  });

  test('short content can preload without a scroll event', () {
    expect(
      shouldAutoLoadMore(
        sentinelScrollOffset: 620,
        scrollOffset: 0,
        viewportDimension: 700,
      ),
      isTrue,
    );
  });

  test('supports a custom preload extent', () {
    expect(
      shouldAutoLoadMore(
        sentinelScrollOffset: 1300,
        scrollOffset: 0,
        viewportDimension: 700,
        preloadExtent: 500,
      ),
      isFalse,
    );
    expect(
      shouldAutoLoadMore(
        sentinelScrollOffset: 1200,
        scrollOffset: 0,
        viewportDimension: 700,
        preloadExtent: 500,
      ),
      isTrue,
    );
  });

  test('rejects invalid viewport geometry', () {
    expect(
      shouldAutoLoadMore(
        sentinelScrollOffset: double.nan,
        scrollOffset: 0,
        viewportDimension: 700,
      ),
      isFalse,
    );
    expect(
      shouldAutoLoadMore(
        sentinelScrollOffset: 100,
        scrollOffset: 0,
        viewportDimension: 0,
      ),
      isFalse,
    );
  });

  testWidgets('parent scroll triggers the next comment page on long content', (
    tester,
  ) async {
    final requests = <String?>[];
    final controller = ScrollController();
    addTearDown(controller.dispose);

    Future<LoadingState<Map<String, dynamic>>> loadPage({
      required String resourceId,
      required String resourceType,
      required String orderBy,
      String? nextUrl,
    }) async {
      requests.add(nextUrl);
      if (nextUrl == null) {
        return Success(_page(['1'], next: 'page-2', total: 2));
      }
      return Success(_page(['2'], isEnd: true, total: 2));
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: CustomScrollView(
              controller: controller,
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 2400)),
                SliverToBoxAdapter(
                  child: InlineCommentWidget(
                    resourceId: 'article-1',
                    resourceType: 'articles',
                    pageLoader: loadPage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requests, [null]);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(requests, [null, 'page-2']);
    expect(find.text('comment 2'), findsOneWidget);
  });

  testWidgets('repeated pagination cursor stops automatic requests', (
    tester,
  ) async {
    final requests = <String?>[];

    Future<LoadingState<Map<String, dynamic>>> loadPage({
      required String resourceId,
      required String resourceType,
      required String orderBy,
      String? nextUrl,
    }) async {
      requests.add(nextUrl);
      return nextUrl == null
          ? Success(_page(['1'], next: 'repeat', total: 2))
          : Success(_page(['2'], next: 'repeat', total: 2));
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: ListView(
              children: [
                InlineCommentWidget(
                  resourceId: 'article-2',
                  resourceType: 'articles',
                  pageLoader: loadPage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requests, [null, 'repeat']);
    expect(find.text('comment 2'), findsOneWidget);
    expect(find.text('查看更多评论'), findsNothing);
  });

  testWidgets('a successful sort reload clears a load-more error', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    Future<LoadingState<Map<String, dynamic>>> loadPage({
      required String resourceId,
      required String resourceType,
      required String orderBy,
      String? nextUrl,
    }) async {
      if (nextUrl != null) return const Error('下一页失败');
      return orderBy == 'ts'
          ? Success(_page(['new'], isEnd: true, total: 1))
          : Success(_page(['old'], next: 'page-2', total: 2));
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: CustomScrollView(
              controller: controller,
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 2400)),
                SliverToBoxAdapter(
                  child: InlineCommentWidget(
                    resourceId: 'article-3',
                    resourceType: 'articles',
                    pageLoader: loadPage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('加载失败，点击重试'), findsOneWidget);

    await tester.tap(find.text('按热度'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('按时间排序'));
    await tester.pumpAndSettle();

    expect(find.text('加载失败，点击重试'), findsNothing);
    expect(find.text('comment new'), findsOneWidget);
  });
}

Map<String, dynamic> _page(
  List<String> ids, {
  String? next,
  bool isEnd = false,
  int total = 0,
}) {
  return {
    'data': ids.map(_comment).toList(),
    'paging': {'is_end': isEnd, 'next': next},
    'counts': {'total_counts': total},
  };
}

Map<String, dynamic> _comment(String id) {
  return {
    'id': id,
    'content': '<p>comment $id</p>',
    'author': {'name': 'tester', 'avatar_url': ''},
    'vote_count': 0,
    'child_comment_count': 0,
    'created_time': 1,
  };
}
