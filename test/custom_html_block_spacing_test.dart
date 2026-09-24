import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/common/widgets/html/custom_html.dart';

void main() {
  for (final tag in ['p', 'h1', 'h2', 'h3', 'h4']) {
    testWidgets(
      '$tag starts below preceding text and separates following text',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SelectionArea(
                child: CustomHtml(
                  content: '<p>Before</p><$tag>Middle</$tag><p>After</p>',
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        Offset position(String word) {
          for (final element in find.byType(RichText).evaluate()) {
            final render = element.renderObject;
            if (render is! RenderParagraph) continue;
            final text = render.text.toPlainText();
            final index = text.indexOf(word);
            if (index < 0) continue;
            final boxes = render.getBoxesForSelection(
              TextSelection(
                baseOffset: index,
                extentOffset: index + word.length,
              ),
            );
            if (boxes.isNotEmpty) {
              return render.localToGlobal(boxes.first.toRect().topLeft);
            }
          }
          throw StateError('Missing rendered text: $word');
        }

        expect(position('Middle').dy, greaterThan(position('Before').dy + 10));
        expect(position('After').dy, greaterThan(position('Middle').dy + 10));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
