import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/services/reading_history_service.dart';
import 'package:tritium/utils/storage.dart';

void main() {
  late Directory storageDirectory;

  setUpAll(() async {
    storageDirectory = await Directory.systemTemp.createTemp(
      'tritium-history-test-',
    );
    await GStorage.init(pathOverride: storageDirectory.path);
  });

  setUp(GStorage.clear);

  tearDownAll(() async {
    await GStorage.close();
    await storageDirectory.delete(recursive: true);
  });

  test(
    'records recent content, deduplicates it and preserves progress',
    () async {
      await ReadingHistoryService.record(
        kind: 'article',
        id: '1',
        title: '第一篇文章',
        preview: '<p>正文摘要</p>',
        url: 'https://zhuanlan.zhihu.com/p/1',
      );
      await ReadingHistoryService.saveProgress('article', '1', 0.42);
      await ReadingHistoryService.record(
        kind: 'answer',
        id: '2',
        title: '第二个回答',
        url: 'https://www.zhihu.com/answer/2',
      );
      await ReadingHistoryService.record(
        kind: 'article',
        id: '1',
        title: '第一篇文章（更新）',
        url: 'https://zhuanlan.zhihu.com/p/1',
      );

      final entries = ReadingHistoryService.entries;
      expect(entries, hasLength(2));
      expect(entries.first.storageId, 'article:1');
      expect(entries.first.title, '第一篇文章（更新）');
      expect(entries.first.progress, closeTo(0.42, 0.001));
      expect(entries.first.preview, '正文摘要');
    },
  );

  test('removes individual entries and clears all history', () async {
    await ReadingHistoryService.record(
      kind: 'question',
      id: '1',
      title: '问题',
      url: 'https://www.zhihu.com/question/1',
    );
    await ReadingHistoryService.record(
      kind: 'pin',
      id: '2',
      title: '想法',
      url: 'https://www.zhihu.com/pin/2',
    );

    await ReadingHistoryService.remove('question', '1');
    expect(ReadingHistoryService.entries.map((entry) => entry.storageId), [
      'pin:2',
    ]);

    await ReadingHistoryService.clear();
    expect(ReadingHistoryService.entries, isEmpty);
  });
}
