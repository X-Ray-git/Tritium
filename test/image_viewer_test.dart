import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/common/widgets/image_viewer.dart';

void main() {
  testWidgets('double-tap zoom remains pannable during a new drag gesture', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ImageViewer(
          imageUrls: ['https://example.invalid/image.png'],
          initialIndex: 0,
        ),
      ),
    );
    await tester.pump();

    final viewer = find.byType(InteractiveViewer);
    expect(tester.widget<InteractiveViewer>(viewer).panEnabled, isFalse);

    await tester.tap(viewer);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(viewer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    var interactiveViewer = tester.widget<InteractiveViewer>(viewer);
    expect(interactiveViewer.panEnabled, isTrue);
    expect(
      interactiveViewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1.01),
    );
    final translationBefore = Offset(
      interactiveViewer.transformationController!.value.storage[12],
      interactiveViewer.transformationController!.value.storage[13],
    );

    await tester.drag(viewer, const Offset(60, 30));
    await tester.pump();
    interactiveViewer = tester.widget<InteractiveViewer>(viewer);
    expect(
      interactiveViewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1.01),
    );
    final translationAfter = Offset(
      interactiveViewer.transformationController!.value.storage[12],
      interactiveViewer.transformationController!.value.storage[13],
    );
    expect(translationAfter, isNot(translationBefore));
    expect(interactiveViewer.panEnabled, isTrue);
    await tester.pump(const Duration(milliseconds: 50));
  });
}
