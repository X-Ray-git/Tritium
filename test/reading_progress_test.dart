import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/common/widgets/reading_progress.dart';
import 'package:tritium/services/reading_history_service.dart';

void main() {
  setUp(() => ReadingHistoryService.persistenceEnabled = false);
  tearDown(() => ReadingHistoryService.persistenceEnabled = true);

  testWidgets('reading progress bar follows its value listenable', (
    tester,
  ) async {
    final progress = ValueNotifier<double>(0.25);
    addTearDown(progress.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: TritiumReadingProgressBar(progress: progress),
          ),
        ),
      ),
    );

    FractionallySizedBox fill = tester.widget(
      find.byType(FractionallySizedBox),
    );
    expect(fill.widthFactor, 0.25);

    progress.value = 0.8;
    await tester.pump();
    fill = tester.widget(find.byType(FractionallySizedBox));
    expect(fill.widthFactor, 0.8);
  });

  testWidgets('body end reaches 100% at the viewport bottom', (tester) async {
    final controller = ScrollController();
    final bodyEndKey = GlobalKey();
    final commentHeight = ValueNotifier<double>(800);
    addTearDown(controller.dispose);
    addTearDown(commentHeight.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              height: 400,
              child: CustomScrollView(
                controller: controller,
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 1000)),
                  SliverToBoxAdapter(child: SizedBox(key: bodyEndKey)),
                  SliverToBoxAdapter(
                    child: ValueListenableBuilder<double>(
                      valueListenable: commentHeight,
                      builder: (context, height, child) =>
                          SizedBox(height: height),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final session = ReadingSession(
      kind: 'article',
      id: 'long',
      scrollController: controller,
      bodyEndKey: bodyEndKey,
    );
    addTearDown(session.dispose);

    session.refresh();
    expect(session.progress.value, 0);
    expect(controller.position.maxScrollExtent, 1400);

    final renderObject = bodyEndKey.currentContext!.findRenderObject()!;
    final viewport = RenderAbstractViewport.of(renderObject);
    final bodyEndAtViewportBottom = viewport
        .getOffsetToReveal(renderObject, 1)
        .offset;
    expect(bodyEndAtViewportBottom, 600);

    controller.jumpTo(bodyEndAtViewportBottom / 2);
    expect(session.progress.value, closeTo(0.5, 0.001));

    commentHeight.value = 1200;
    await tester.pump();
    session.refresh();
    expect(session.progress.value, closeTo(0.5, 0.001));

    controller.jumpTo(bodyEndAtViewportBottom);
    expect(session.progress.value, 1);
    expect(controller.offset, lessThan(controller.position.maxScrollExtent));
  });

  testWidgets('a body already contained by the viewport starts at 100%', (
    tester,
  ) async {
    final controller = ScrollController();
    final bodyEndKey = GlobalKey();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              height: 400,
              child: CustomScrollView(
                controller: controller,
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 200)),
                  SliverToBoxAdapter(child: SizedBox(key: bodyEndKey)),
                  const SliverToBoxAdapter(child: SizedBox(height: 800)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final session = ReadingSession(
      kind: 'article',
      id: 'short',
      scrollController: controller,
      bodyEndKey: bodyEndKey,
    );
    addTearDown(session.dispose);

    session.refresh();
    expect(controller.position.maxScrollExtent, 600);
    expect(session.progress.value, 1);

    controller.jumpTo(200);
    expect(session.progress.value, 1);
  });
}
