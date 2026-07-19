import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/services/content_link_service.dart';

void main() {
  group('ContentLinkTarget', () {
    test('parses a question answer URL', () {
      final target = ContentLinkTarget.parse(
        'https://www.zhihu.com/question/123/answer/456',
      );

      expect(target?.kind, ContentLinkKind.answer);
      expect(target?.id, '456');
      expect(target?.questionId, '123');
    });

    test('parses custom article and pin links', () {
      expect(
        ContentLinkTarget.parse('zhihu://article/99')?.kind,
        ContentLinkKind.article,
      );
      expect(
        ContentLinkTarget.parse('zhihu://pin/88')?.kind,
        ContentLinkKind.pin,
      );
    });

    test('keeps non-Zhihu HTTPS links external', () {
      final target = ContentLinkTarget.parse('https://example.test/read');

      expect(target?.kind, ContentLinkKind.external);
      expect(target?.uri.host, 'example.test');
    });

    test('converts a custom video link to a browser URL', () {
      final target = ContentLinkTarget.parse('zhihu://zvideo/77');

      expect(target?.kind, ContentLinkKind.video);
      expect(target?.uri.toString(), 'https://www.zhihu.com/zvideo/77');
    });

    test('rejects unsupported schemes and malformed links', () {
      expect(ContentLinkTarget.parse('javascript:alert(1)'), isNull);
      expect(ContentLinkTarget.parse('not a URL'), isNull);
    });
  });
}
