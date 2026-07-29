import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/common/widgets/html/chunked_html_sliver.dart';
import 'package:tritium/common/widgets/html/html_chunker.dart';

void main() {
  testWidgets('long content lays out every chunk in one stable sliver', (
    tester,
  ) async {
    final content = List.generate(
      8,
      (index) => '<p>block-$index ${'x' * 1800}</p>',
      growable: false,
    ).join();
    final chunks = HtmlChunker.parseSync(content);
    var ready = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              ChunkedHtmlSliver(content: content, onReady: () => ready = true),
            ],
          ),
        ),
      ),
    );

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump();
    expect(ready, isTrue);

    final adapter = tester.widget<SliverToBoxAdapter>(
      find.byType(SliverToBoxAdapter),
    );
    final column = adapter.child! as Column;
    expect(column.children, hasLength(chunks.length));
  });
}
