import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as parser;
import 'package:tritium/common/widgets/html/custom_html.dart';

void main() {
  Future<void> render(WidgetTester tester, String content) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SelectionArea(child: CustomHtml(content: content)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  String visibleSourceText(WidgetTester tester) => tester
      .widgetList<Html>(find.byType(Html))
      .map((html) => parser.parseFragment(html.data ?? '').text ?? '')
      .join();

  testWidgets('bracket emoji do not leak image markup after fragmentation', (
    tester,
  ) async {
    await render(tester, '<p>前[微笑][赞]后[未知表情]</p>');
    expect(find.byType(CachedNetworkImage), findsNWidgets(2));
    expect(visibleSourceText(tester), '前后[未知表情]');
    for (final html in tester.widgetList<Html>(find.byType(Html))) {
      final images = parser.parseFragment(html.data!).querySelectorAll('img');
      expect(images.map((image) => image.attributes['alt']), ['[微笑]', '[赞]']);
    }
  });

  testWidgets('existing image alt and link attributes remain intact', (
    tester,
  ) async {
    await render(
      tester,
      '<p><a href="/question/1" title="[赞]">文字</a>'
      '<img class="emoji" src="https://example.com/smile.png" alt="[微笑]"></p>',
    );
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(visibleSourceText(tester), '文字');
    final dom = parser.parseFragment(
      tester.widget<Html>(find.byType(Html)).data!,
    );
    expect(dom.querySelector('img')!.attributes['alt'], '[微笑]');
    expect(dom.querySelector('a')!.attributes['title'], '[赞]');
    expect(dom.querySelector('a')!.attributes['href'], '/question/1');
  });

  testWidgets('nested lists and quotes normalize emoji only once', (
    tester,
  ) async {
    await render(
      tester,
      '<p>开始[微笑]</p><ul><li>列表[赞]'
      '<blockquote>引用[微笑]</blockquote></li></ul>',
    );
    expect(find.byType(CachedNetworkImage), findsNWidgets(3));
    expect(visibleSourceText(tester), '开始列表引用');
  });

  testWidgets('code literals and escaped text remain text', (tester) async {
    await render(
      tester,
      '<p>&lt;img&gt; &amp; <code>[微笑]</code></p>'
      '<pre>[赞]</pre>',
    );
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(visibleSourceText(tester), contains('<img> & [微笑]'));
    expect(visibleSourceText(tester), contains('[赞]'));
  });
}
