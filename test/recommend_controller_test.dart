import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tritium/http/init.dart';
import 'package:tritium/pages/home/recommend_page.dart';
import 'package:tritium/services/preload_service.dart';

void main() {
  Map<String, dynamic> answer(String id) => {
    'target': {'type': 'answer', 'id': id},
  };

  Success<Map<String, dynamic>> page(
    List<Map<String, dynamic>> items, {
    String? next,
  }) => Success({
    'data': items,
    'paging': {'is_end': next == null, 'next': next},
  });

  setUp(() {
    Get.testMode = true;
    Get.reset();
    PreloadService.instance.clearCache();
  });

  tearDown(Get.reset);

  test('refresh replaces the list with only new session content', () async {
    final responses = <LoadingState<Map<String, dynamic>>>[
      page([answer('1'), answer('2')]),
      page([answer('2'), answer('3')]),
    ];
    final controller = RecommendController(
      pageLoader: ({nextUrl}) async => responses.removeAt(0),
    );

    await controller.loadData();
    expect(controller.feedList.map((item) => item['target']['id']), ['1', '2']);

    await controller.loadData(forceNetwork: true);
    expect(controller.feedList.map((item) => item['target']['id']), ['3']);
  });

  test(
    'an all-duplicate refresh retains the current list and stops paging',
    () async {
      final responses = <LoadingState<Map<String, dynamic>>>[
        page([answer('1'), answer('2')], next: 'page-2'),
        page([answer('1'), answer('2')], next: 'page-2'),
      ];
      final controller = RecommendController(
        pageLoader: ({nextUrl}) async => responses.removeAt(0),
      );

      await controller.loadData();
      expect(controller.hasMore, isTrue);

      await controller.loadData(forceNetwork: true);
      expect(controller.feedList.map((item) => item['target']['id']), [
        '1',
        '2',
      ]);
      expect(controller.hasMore, isFalse);
    },
  );

  test('an empty-new-content page stops repeated load-more requests', () async {
    var requestCount = 0;
    final controller = RecommendController(
      pageLoader: ({nextUrl}) async {
        requestCount++;
        if (nextUrl == null) {
          return page([answer('1')], next: 'page-2');
        }
        return page([answer('1')], next: 'page-3');
      },
    );

    await controller.loadData();
    await controller.loadMore();
    await controller.loadMore();

    expect(requestCount, 2);
    expect(controller.hasMore, isFalse);
    expect(controller.feedList, hasLength(1));
  });
}
