import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/models/common/paging_info.dart';

void main() {
  group('PagingInfo', () {
    test('keeps a valid next page', () {
      final paging = PagingInfo.fromJson({
        'is_end': false,
        'next': 'https://example.test/page/2',
      });

      expect(paging.isEnd, isFalse);
      expect(paging.hasNext, isTrue);
      expect(paging.nextUrl, 'https://example.test/page/2');
    });

    test('stops on an explicit final page', () {
      final paging = PagingInfo.fromJson({
        'is_end': true,
        'next': 'https://example.test/page/2',
      });

      expect(paging.isEnd, isTrue);
      expect(paging.nextUrl, isNull);
    });

    test('treats missing and empty next links as final pages', () {
      expect(PagingInfo.fromJson(null).hasNext, isFalse);
      expect(
        PagingInfo.fromJson({'is_end': false, 'next': ''}).hasNext,
        isFalse,
      );
    });
  });
}
