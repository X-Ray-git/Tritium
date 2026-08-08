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

    test('falls back to a browser URL for unsupported Zhihu destinations', () {
      final topic = ContentLinkTarget.parse('zhihu://topic/19550517');
      final column = ContentLinkTarget.parse('https://zhuanlan.zhihu.com/c_1');

      expect(topic?.kind, ContentLinkKind.external);
      expect(topic?.uri.toString(), 'https://www.zhihu.com/topic/19550517');
      expect(column?.kind, ContentLinkKind.external);
    });

    test('reuses the user page for organization links', () {
      final org = ContentLinkTarget.parse('https://www.zhihu.com/org/example');

      expect(org?.kind, ContentLinkKind.user);
      expect(org?.id, 'example');
    });

    test('rejects unsupported schemes and malformed links', () {
      expect(ContentLinkTarget.parse('javascript:alert(1)'), isNull);
      expect(ContentLinkTarget.parse('data:text/html,<script>'), isNull);
      expect(ContentLinkTarget.parse('file:///etc/passwd'), isNull);
      expect(ContentLinkTarget.parse('not a URL'), isNull);
      expect(ContentLinkTarget.parse(''), isNull);
      expect(ContentLinkTarget.parse('   '), isNull);
      expect(ContentLinkTarget.parse('#fragment'), isNull);
    });
  });

  group('URL normalization', () {
    test('trims surrounding whitespace', () {
      final target = ContentLinkTarget.parse(
        '  https://www.zhihu.com/question/1  ',
      );

      expect(target?.kind, ContentLinkKind.question);
      expect(target?.id, '1');
    });

    test('supports protocol-relative URLs', () {
      final target = ContentLinkTarget.parse('//www.zhihu.com/question/42');

      expect(target?.kind, ContentLinkKind.question);
      expect(target?.id, '42');
      expect(target?.uri.scheme, 'https');
    });

    test('supports site-relative paths with a leading slash', () {
      final target = ContentLinkTarget.parse('/answer/555');

      expect(target?.kind, ContentLinkKind.answer);
      expect(target?.id, '555');
    });

    test('supports recognizable site paths without a leading slash', () {
      expect(
        ContentLinkTarget.parse('question/7')?.kind,
        ContentLinkKind.question,
      );
      expect(
        ContentLinkTarget.parse('people/url-token')?.kind,
        ContentLinkKind.user,
      );
    });

    test('supports host-like URLs without a scheme', () {
      final target = ContentLinkTarget.parse('www.zhihu.com/question/9');

      expect(target?.kind, ContentLinkKind.question);
      expect(target?.id, '9');
    });

    test('preserves query and fragment while adding a scheme', () {
      final target = ContentLinkTarget.parse(
        'example.test/read?token=abc#section-2',
      );

      expect(target?.kind, ContentLinkKind.external);
      expect(
        target?.uri.toString(),
        'https://example.test/read?token=abc#section-2',
      );
    });

    test('unwraps a scheme-less link.zhihu.com target', () {
      final target = ContentLinkTarget.parse(
        'link.zhihu.com/?target=https%3A%2F%2Fwww.zhihu.com%2Fquestion%2F321',
      );

      expect(target?.kind, ContentLinkKind.question);
      expect(target?.id, '321');
    });

    test('unwraps link.zhihu.com targets', () {
      final target = ContentLinkTarget.parse(
        'https://link.zhihu.com/?target=https%3A%2F%2Fwww.zhihu.com%2Fquestion%2F123',
      );

      expect(target?.kind, ContentLinkKind.question);
      expect(target?.id, '123');
    });

    test('unwraps nested link.zhihu.com redirects', () {
      final inner = Uri.encodeComponent(
        'https://link.zhihu.com/?target=https%3A%2F%2Fwww.zhihu.com%2Fanswer%2F9',
      );
      final target = ContentLinkTarget.parse(
        'https://link.zhihu.com/?target=$inner',
      );

      expect(target?.kind, ContentLinkKind.answer);
      expect(target?.id, '9');
    });

    test('stops at cyclic or runaway link.zhihu.com redirects', () {
      // 超过最大解包深度的跳转链（等价于循环重定向）必须被拒绝。
      String url = 'hop';
      for (var i = 0; i < 6; i++) {
        url = 'https://link.zhihu.com/?target=${Uri.encodeComponent(url)}';
      }
      expect(ContentLinkTarget.parse(url), isNull);
    });

    test('rejects an empty link.zhihu.com target', () {
      expect(
        ContentLinkTarget.parse('https://link.zhihu.com/?target='),
        isNull,
      );
    });
  });

  group('Typed path parsing', () {
    test('parses plural deep links and http paths', () {
      expect(
        ContentLinkTarget.parse('zhihu://questions/1')?.kind,
        ContentLinkKind.question,
      );
      expect(
        ContentLinkTarget.parse('zhihu://answers/2')?.kind,
        ContentLinkKind.answer,
      );
      expect(
        ContentLinkTarget.parse('zhihu://articles/3')?.kind,
        ContentLinkKind.article,
      );
      expect(
        ContentLinkTarget.parse('zhihu://pins/4')?.kind,
        ContentLinkKind.pin,
      );
      expect(
        ContentLinkTarget.parse('https://www.zhihu.com/questions/10')?.kind,
        ContentLinkKind.question,
      );
      expect(
        ContentLinkTarget.parse('https://www.zhihu.com/answers/11')?.kind,
        ContentLinkKind.answer,
      );
      expect(
        ContentLinkTarget.parse('https://www.zhihu.com/articles/12')?.kind,
        ContentLinkKind.article,
      );
      expect(
        ContentLinkTarget.parse('https://www.zhihu.com/pins/13')?.kind,
        ContentLinkKind.pin,
      );
    });

    test('parses question + answer combined paths in both orders', () {
      final viaQuestion = ContentLinkTarget.parse(
        'https://www.zhihu.com/question/1/answer/2',
      );
      expect(viaQuestion?.kind, ContentLinkKind.answer);
      expect(viaQuestion?.id, '2');
      expect(viaQuestion?.questionId, '1');

      final viaDeepLink = ContentLinkTarget.parse(
        'zhihu://question/3/answer/4',
      );
      expect(viaDeepLink?.kind, ContentLinkKind.answer);
      expect(viaDeepLink?.id, '4');
      expect(viaDeepLink?.questionId, '3');
    });

    test('parses zhuanlan articles', () {
      final target = ContentLinkTarget.parse(
        'https://zhuanlan.zhihu.com/p/123456',
      );

      expect(target?.kind, ContentLinkKind.article);
      expect(target?.id, '123456');
    });

    test('parses /p/{id} short article paths', () {
      final target = ContentLinkTarget.parse('https://www.zhihu.com/p/987');

      expect(target?.kind, ContentLinkKind.article);
      expect(target?.id, '987');
    });

    test('parses appview paths', () {
      expect(
        ContentLinkTarget.parse(
          'https://www.zhihu.com/appview/answer/21',
        )?.kind,
        ContentLinkKind.answer,
      );
      expect(
        ContentLinkTarget.parse('https://www.zhihu.com/appview/p/22')?.kind,
        ContentLinkKind.article,
      );
      expect(
        ContentLinkTarget.parse('https://www.zhihu.com/appview/pin/23')?.kind,
        ContentLinkKind.pin,
      );
    });

    test('parses oia article paths', () {
      final target = ContentLinkTarget.parse(
        'https://zhuanlan.zhihu.com/oia/articles/555',
      );

      expect(target?.kind, ContentLinkKind.article);
      expect(target?.id, '555');
    });

    test('parses people profiles', () {
      final target = ContentLinkTarget.parse(
        'https://www.zhihu.com/people/tritium-dev',
      );

      expect(target?.kind, ContentLinkKind.user);
      expect(target?.id, 'tritium-dev');
    });

    test('parses video paths as browser fallbacks', () {
      expect(
        ContentLinkTarget.parse('https://www.zhihu.com/zvideo/100')?.kind,
        ContentLinkKind.video,
      );
      expect(
        ContentLinkTarget.parse('https://www.zhihu.com/video/101')?.kind,
        ContentLinkKind.video,
      );
    });

    test('parses zhihu:// deep links with www host prefix', () {
      final target = ContentLinkTarget.parse(
        'zhihu://www.zhihu.com/question/5',
      );

      expect(target?.kind, ContentLinkKind.question);
      expect(target?.id, '5');
    });

    test('does not route malformed content ids into native pages', () {
      expect(
        ContentLinkTarget.parse(
          'https://www.zhihu.com/question/not-a-number',
        )?.kind,
        ContentLinkKind.external,
      );
      expect(
        ContentLinkTarget.parse('zhihu://answers/not-a-number')?.kind,
        ContentLinkKind.external,
      );
    });
  });
}
