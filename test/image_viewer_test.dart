import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/common/widgets/image_viewer.dart';
import 'package:tritium/common/widgets/interactiveviewer_gallery/interactive_viewer_boundary.dart';

void main() {
  Future<void> pumpViewer(
    WidgetTester tester, {
    List<String> imageUrls = const ['https://example.invalid/image.png'],
  }) async {
    await tester.pumpWidget(
      MaterialApp(home: ImageViewer(imageUrls: imageUrls, initialIndex: 0)),
    );
    await tester.pump();
  }

  InteractiveViewerBoundary viewerOf(WidgetTester tester) {
    return tester.widget<InteractiveViewerBoundary>(
      find.byType(InteractiveViewerBoundary),
    );
  }

  double scaleOf(WidgetTester tester) {
    return viewerOf(tester).controller.value.getMaxScaleOnAxis();
  }

  testWidgets('double-tap zoom remains pannable during a new drag gesture', (
    tester,
  ) async {
    await pumpViewer(tester);
    final viewer = find.byType(InteractiveViewerBoundary);

    await tester.tap(viewer);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(viewer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(scaleOf(tester), greaterThan(1.01));
    final controller = viewerOf(tester).controller;
    final translationBefore = Offset(
      controller.value.storage[12],
      controller.value.storage[13],
    );

    await tester.drag(viewer, const Offset(60, 30));
    await tester.pump();

    expect(scaleOf(tester), greaterThan(1.01));
    final translationAfter = Offset(
      controller.value.storage[12],
      controller.value.storage[13],
    );
    expect(translationAfter, isNot(translationBefore));
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('pinch zooms when both pointers land before movement', (
    tester,
  ) async {
    await pumpViewer(tester);
    final center = tester.getCenter(find.byType(InteractiveViewerBoundary));
    final first = await tester.createGesture(pointer: 1);
    final second = await tester.createGesture(pointer: 2);

    await first.down(center + const Offset(-40, 0));
    await second.down(center + const Offset(40, 0));
    await tester.pump();
    await first.moveTo(center + const Offset(-120, 0));
    await second.moveTo(center + const Offset(120, 0));
    await tester.pump();

    expect(scaleOf(tester), greaterThan(1.01));
    await first.up();
    await second.up();
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('pinch takes over after the first pointer has started moving', (
    tester,
  ) async {
    await pumpViewer(tester);
    final center = tester.getCenter(find.byType(InteractiveViewerBoundary));
    final first = await tester.createGesture(pointer: 3);
    final second = await tester.createGesture(pointer: 4);

    await first.down(center + const Offset(-40, 0));
    await first.moveBy(const Offset(0, 30));
    await tester.pump();
    await second.down(center + const Offset(40, 0));
    await first.moveTo(center + const Offset(-120, 0));
    await second.moveTo(center + const Offset(120, 0));
    await tester.pump();

    expect(scaleOf(tester), greaterThan(1.01));
    await first.up();
    await second.up();
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('cancelled pull-down returns the image to its origin', (
    tester,
  ) async {
    await pumpViewer(tester);
    final viewer = find.byType(InteractiveViewerBoundary);

    await tester.drag(viewer, const Offset(0, 70));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(ImageViewer), findsOneWidget);
    expect(
      tester
          .widget<SlideTransition>(
            find.descendant(of: viewer, matching: find.byType(SlideTransition)),
          )
          .position
          .value,
      equals(Offset.zero),
    );
  });

  testWidgets('horizontal swipe still changes images at the initial scale', (
    tester,
  ) async {
    await pumpViewer(
      tester,
      imageUrls: const [
        'https://example.invalid/first.png',
        'https://example.invalid/second.png',
      ],
    );

    expect(find.text('1 / 2'), findsOneWidget);
    await tester.drag(
      find.byType(InteractiveViewerBoundary),
      const Offset(-500, 0),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('2 / 2'), findsOneWidget);
    expect(scaleOf(tester), equals(1));
  });
}
