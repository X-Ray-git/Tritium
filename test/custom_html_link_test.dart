import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/common/widgets/html/custom_html.dart';

void main() {
  Widget host(String html, {void Function(String)? onLinkTap}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CustomHtml(
            content: html,
            onLinkTap: (url, attributes, element) {
              if (url != null) onLinkTap?.call(url);
            },
          ),
        ),
      ),
    );
  }

  testWidgets('plain text links are tappable', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      host(
        '<p><a href="https://www.zhihu.com/question/1">这个问题</a></p>',
        onLinkTap: tapped.add,
      ),
    );
    await tester.pump();

    expect(find.text('这个问题', findRichText: true), findsOneWidget);
    final rect = tester.getRect(find.text('这个问题', findRichText: true));
    await tester.tapAt(Offset(rect.left + 30, rect.center.dy));
    expect(tapped, ['https://www.zhihu.com/question/1']);
  });

  testWidgets('nested spans inside a link are preserved', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      host(
        '<p><a href="https://www.zhihu.com/question/2">普通文字'
        '<strong>加粗</strong>与<em>斜体</em></a></p>',
        onLinkTap: tapped.add,
      ),
    );
    await tester.pump();

    // 嵌套 span 的文本都保留在同一段落里。
    final paragraph = find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText() == '普通文字加粗与斜体',
    );
    expect(paragraph, findsOneWidget);

    // 整个 <a> 是一个可点击段落，点任意位置都命中链接。
    final rect = tester.getRect(paragraph);
    await tester.tapAt(Offset(rect.left + 30, rect.center.dy));
    expect(tapped, ['https://www.zhihu.com/question/2']);
  });

  testWidgets('relative Zhihu links go through the same handler', (
    tester,
  ) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      host('<p><a href="/question/3">相对路径</a></p>', onLinkTap: tapped.add),
    );
    await tester.pump();

    final rect = tester.getRect(find.text('相对路径', findRichText: true));
    await tester.tapAt(Offset(rect.left + 30, rect.center.dy));
    expect(tapped, ['/question/3']);
  });

  testWidgets('text without href is not tappable', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      host(
        '<p><a style="color: #3961FF">没有 href 的蓝字</a></p>',
        onLinkTap: tapped.add,
      ),
    );
    await tester.pump();

    expect(find.text('没有 href 的蓝字', findRichText: true), findsOneWidget);
    final rect = tester.getRect(find.text('没有 href 的蓝字', findRichText: true));
    await tester.tapAt(Offset(rect.left + 30, rect.center.dy));
    expect(tapped, isEmpty);
  });

  testWidgets('fragment links are never passed to the browser handler', (
    tester,
  ) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      host(
        '<p><a href="#footnote-1">脚注</a></p>',
        onLinkTap: (url) {
          if (!url.startsWith('#')) tapped.add(url);
        },
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.text('脚注', findRichText: true));
    await tester.tapAt(Offset(rect.left + 30, rect.center.dy));
    expect(tapped, isEmpty);
  });

  testWidgets('comment image links render a rounded thumbnail', (tester) async {
    await tester.pumpWidget(
      host(
        '<p><a href="https://picx.zhimg.com/80/x.png" '
        'data-text="查看图片">查看图片</a></p>',
      ),
    );
    await tester.pump();

    final clip = tester.widget<ClipRRect>(
      find.ancestor(
        of: find.byType(CachedNetworkImage),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(clip.borderRadius, BorderRadius.circular(8));
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('normal text links are not rendered as image thumbnails', (
    tester,
  ) async {
    await tester.pumpWidget(
      host('<p><a href="https://www.zhihu.com/question/9">查看图片的解释文字</a></p>'),
    );
    await tester.pump();

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.text('查看图片的解释文字'), findsOneWidget);
  });
}
