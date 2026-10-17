import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tritium/common/widgets/html/custom_html.dart';
import 'package:tritium/common/widgets/html/html_chunker.dart';
import 'package:tritium/router/app_pages.dart';
import 'package:tritium/services/content_link_service.dart';
import 'package:tritium/services/video_service.dart';

void main() {
  test('Lens uses HD and falls back past missing or unsafe variants', () {
    expect(
      VideoService.lensUrl({
        'playlist': {
          'HD': {'play_url': 'https://cdn.test/hd.mp4'},
          'SD': {'play_url': 'https://cdn.test/sd.mp4'},
        },
      }).toString(),
      'https://cdn.test/hd.mp4',
    );
    expect(
      VideoService.lensUrl({
        'playlist': {
          'HD': {'play_url': 'javascript:alert(1)'},
          'LD': {'play_url': 'https://cdn.test/ld.mp4'},
        },
      }).toString(),
      'https://cdn.test/ld.mp4',
    );
    for (final data in [
      null,
      [],
      {},
      {'playlist': []},
    ]) {
      expect(VideoService.lensUrl(data), isNull);
    }
  });

  test('play info chooses highest usable bitrate and tries alternate URLs', () {
    expect(
      VideoService.playInfoUrl({
        'video_play': {
          'playlist': {
            'mp4': [
              {
                'bitrate': 30,
                'url': ['http://unsafe.test/video'],
              },
              {
                'bitrate': 10,
                'url': ['https://cdn.test/low'],
              },
              {
                'bitrate': 20,
                'url': ['', 'https://cdn.test/high'],
              },
            ],
          },
        },
      }).toString(),
      'https://cdn.test/high',
    );
    expect(VideoService.playInfoUrl({'video_play': []}), isNull);
    expect(VideoService.playInfoUrl(null), isNull);
    expect(VideoService.mediaUri('https://user:password@cdn.test/v'), isNull);
  });

  test('video and zvideo deep links preserve distinct identities', () {
    expect(
      ContentLinkTarget.parse('zhihu://video/123')?.uri.toString(),
      'https://www.zhihu.com/video/123',
    );
    expect(
      ContentLinkTarget.parse('zhihu://zvideo/123')?.uri.toString(),
      'https://www.zhihu.com/zvideo/123',
    );
  });

  test('gallery excludes video covers but retains normal images', () {
    expect(
      HtmlChunker.extractImageUrls(
        '<img src="https://pic.test/photo?a=1&amp;b=2">',
      ),
      ['https://pic.test/photo?a=1&b=2'],
    );
    expect(
      HtmlChunker.parseSync(
        '<a class="video-box" data-lens-id="123"><img src="https://pic.test/cover.jpg"></a>',
      ).join(),
      contains('video-box'),
    );
    expect(
      HtmlChunker.extractImageUrls(
        '<a class="video-box"><img src="https://pic.test/cover.jpg"></a>'
        '<img src="https://pic.test/photo.jpg">',
      ),
      ['https://pic.test/photo.jpg'],
    );
  });

  test('invalid media ID fails before any request', () async {
    await expectLater(VideoService.resolve('../123'), throwsFormatException);
  });

  testWidgets('nested video poster and title open a single video target', (
    tester,
  ) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomHtml(
            content:
                '<a class="video-box" data-lens-id="123" data-name="测试视频" '
                'href="https://link.zhihu.com/?target=https%3A%2F%2Fwww.zhihu.com%2Fvideo%2F123">'
                '<img src=""><span>old title</span></a>',
            onLinkTap: (url, _, _) => taps.add(url!),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('测试视频'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_circle_fill));
    expect(taps, ['https://www.zhihu.com/video/123']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('video link opens native route with actual content context', (
    tester,
  ) async {
    Get.testMode = true;
    addTearDown(() {
      ContentLinkService.resetNavigationStateForTesting();
      Get.reset();
    });
    dynamic received;
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage(name: '/', page: () => const Scaffold()),
          GetPage(
            name: Routes.video,
            page: () {
              received = Get.arguments;
              return const Scaffold(body: Text('player route'));
            },
          ),
        ],
      ),
    );
    ContentLinkService.open(
      '/video/123',
      videoContext: (id: '456', type: 'answer'),
    );
    await tester.pumpAndSettle();
    expect(find.text('player route'), findsOneWidget);
    expect(received['videoId'], '123');
    expect(received['context'], (id: '456', type: 'answer'));
  });
}
