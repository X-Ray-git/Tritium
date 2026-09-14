import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:tritium/common/widgets/html/custom_html.dart';

void main() {
  Future<String?> selected(WidgetTester tester, String html) async {
    SelectedContent? value;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: SelectionArea(
            onSelectionChanged: (next) => value = next,
            child: SizedBox(width: 600, child: CustomHtml(content: html)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final target = find.byType(RichText).evaluate().firstWhere((element) {
      final object = element.renderObject;
      return object is RenderParagraph &&
          object.text.toPlainText().contains('selection');
    });
    final paragraph = target.renderObject! as RenderParagraph;
    final plain = paragraph.text.toPlainText();
    final offset = plain.indexOf('selection') + 3;
    final point = paragraph.localToGlobal(
      paragraph.getOffsetForCaret(
            TextPosition(offset: offset),
            const Rect.fromLTWH(0, 0, 2, 20),
          ) +
          Offset(0, paragraph.preferredLineHeight - 2),
    );
    await tester.longPressAt(point);
    await tester.pump();
    return value?.plainText;
  }

  for (final sample in <String, String>{
    'paragraph': '<p>Tritium Android paragraph selection available.</p>',
    'list':
        '<ol><li><p>Tritium Android listed selection available.</p></li></ol>',
    'quote':
        '<blockquote><p>Tritium quoted selection available.</p></blockquote>',
    'code': '<p>Tritium before <code>selection</code> after.</p>',
    'heading': '<h2>Tritium heading selection available.</h2>',
    'mixed list':
        '<p>Before.</p><ol><li>Mixed listed selection available.</li></ol><p>After.</p>',
    'mixed quote':
        '<p>Before.</p><blockquote>Mixed quoted selection available.</blockquote><p>After.</p>',
    'nested quote in list':
        '<ul><li>Before.<blockquote>Nested quoted selection available.</blockquote></li></ul>',
    'escaped plain text': '<p>Comparison &lt; selection &amp; rendering.</p>',
  }.entries) {
    testWidgets(
      sample.key,
      (tester) async =>
          expect(await selected(tester, sample.value), contains('selection')),
    );
  }

  testWidgets('keeps the parser alive across an unrelated parent rebuild', (
    tester,
  ) async {
    final rebuild = ValueNotifier<int>(0);
    addTearDown(rebuild.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<int>(
            valueListenable: rebuild,
            builder: (context, version, child) => CustomHtml(
              content: '<p>Stable parser selection text.</p>',
              fontSize: 16 + version * 0,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final parserBefore = tester.element(find.byType(HtmlParser));

    rebuild.value++;
    await tester.pump();

    expect(tester.element(find.byType(HtmlParser)), same(parserBefore));
  });
}
