import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/common/widgets/html/custom_html.dart';

void main() {
  Future<void> pumpHtml(WidgetTester tester, String html) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: CustomHtml(content: html)),
        ),
      ),
    );
    await tester.pump();
  }

  /// 代码块容器：全宽、8px 圆角、横向滚动、复制按钮。
  final codeBlockFinder = find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration! as BoxDecoration).borderRadius ==
            BorderRadius.circular(8),
  );

  testWidgets('inline code renders as an inline capsule, not a block', (
    tester,
  ) async {
    await pumpHtml(tester, '<p>运行 <code>flutter test</code> 即可</p>');

    // 行内代码不产生整行代码块容器。
    expect(codeBlockFinder, findsNothing);
    // 行内代码是带 6px 圆角的半透明胶囊。
    final capsules = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).borderRadius ==
              BorderRadius.circular(6),
    );
    expect(capsules, findsOneWidget);
  });

  testWidgets('<pre><code> produces exactly one code block container', (
    tester,
  ) async {
    await pumpHtml(
      tester,
      '<pre><code>void main() {\n  print("hi");\n}</code></pre>',
    );

    expect(codeBlockFinder, findsOneWidget);
    // 没有第二层代码背景（行内胶囊不得出现在代码块里）。
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).borderRadius ==
                BorderRadius.circular(6),
      ),
      findsNothing,
    );
  });

  testWidgets('long code lines scroll horizontally instead of wrapping', (
    tester,
  ) async {
    final longLine = List.filled(120, 'x').join();
    await pumpHtml(tester, '<pre><code>$longLine</code></pre>');

    final hScrolls = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    expect(hScrolls, findsOneWidget);
  });

  testWidgets('copy button flips to a check mark after copying', (
    tester,
  ) async {
    await pumpHtml(tester, '<pre><code>print("hello");</code></pre>');

    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    await tester.tap(find.byIcon(Icons.copy_rounded));
    // Clipboard.setData 需要真实异步通道；完成后切到勾选状态。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();

    // 复制成功后切换为勾选状态，约 1.2 秒后恢复。
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsNothing);

    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('wide tables use horizontal scrolling without throwing', (
    tester,
  ) async {
    await pumpHtml(
      tester,
      '<table><tr><th>A</th><th>B</th><th>C</th><th>D</th><th>E</th></tr>'
      '<tr><td>1</td><td>2</td><td>3</td><td>4</td><td>5</td></tr></table>',
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsOneWidget,
    );
  });
}
