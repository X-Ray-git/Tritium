import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/common/widgets/html/custom_html.dart';

void main() {
  Future<CachedNetworkImage> renderFigure(
    WidgetTester tester,
    String imageAttributes,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              child: CustomHtml(
                content:
                    '<figure><img src="https://example.invalid/image.png" '
                    '$imageAttributes></figure>',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
  }

  testWidgets('figure does not add a fixed horizontal image gutter', (
    tester,
  ) async {
    final image = await renderFigure(tester, '');
    expect(image.width, 320);
  });

  testWidgets('figure image still respects its declared width', (tester) async {
    final image = await renderFigure(tester, 'width="120"');
    expect(image.width, 120);
  });
}
