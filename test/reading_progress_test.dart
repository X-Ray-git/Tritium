import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/common/widgets/reading_progress.dart';

void main() {
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
}
