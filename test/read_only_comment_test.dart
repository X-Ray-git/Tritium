import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/common/theme/theme_utils.dart';
import 'package:tritium/common/widgets/child_comment_panel.dart';
import 'package:tritium/common/widgets/html/compact_html_preview.dart';
import 'package:tritium/common/widgets/unified_comment_item.dart';

void main() {
  testWidgets('vote count is visible but is not an action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeUtils.light(),
        home: const Scaffold(
          body: UnifiedCommentItem(
            resourceId: 'answer-1',
            resourceType: 'answers',
            comment: {
              'id': 'comment-1',
              'content': '<p>只读评论</p>',
              'vote_count': 12,
              'child_comment_count': 0,
              'author': {'name': '测试用户'},
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('只读评论'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('点赞'), findsNothing);

    final voteIcon = find.byIcon(Icons.thumb_up_outlined);
    expect(voteIcon, findsOneWidget);
    expect(
      find.ancestor(of: voteIcon, matching: find.byType(InkWell)),
      findsNothing,
    );
  });

  testWidgets('inline child previews load bracket and HTML emoji', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeUtils.light(),
        home: const Scaffold(
          body: UnifiedCommentItem(
            resourceId: 'answer-1',
            resourceType: 'answers',
            enableRepliesNavigation: false,
            comment: {
              'id': 'comment-1',
              'content': '<p>主评论</p>',
              'child_comment_count': 3,
              'author': {'name': '主评论用户'},
              'child_comments': [
                {
                  'content': '<p>方括号表情[捂脸]</p>',
                  'author': {'name': '用户甲'},
                },
                {
                  'content':
                      '<p>HTML 表情<img class="emoji" '
                      'src="https://example.com/emoji.png" alt="[测试]"></p>',
                  'author': {'name': '用户乙'},
                },
                {
                  'content':
                      '<p>普通附件<img '
                      'src="https://example.com/attachment.png"></p>',
                  'author': {'name': '用户丙'},
                },
              ],
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final images = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .map((image) => image.imageUrl)
        .toList();
    expect(
      images,
      contains(
        'https://pic1.zhimg.com/v2-b62e608e405aeb33cd52830218f561ea.png',
      ),
    );
    expect(images, contains('https://example.com/emoji.png'));
    expect(images, isNot(contains('https://example.com/attachment.png')));
  });

  testWidgets('inline child preview width does not depend on reply length', (
    tester,
  ) async {
    Future<double> pumpPreview(String content) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeUtils.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: UnifiedCommentItem(
                  resourceId: 'answer-1',
                  resourceType: 'answers',
                  enableRepliesNavigation: false,
                  comment: {
                    'id': 'comment-1',
                    'content': '<p>主评论</p>',
                    'child_comment_count': 1,
                    'author': const {'name': '主评论用户'},
                    'child_comments': [
                      {
                        'content': '<p>$content</p>',
                        'author': const {'name': '用户甲'},
                      },
                    ],
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final previewInk = find.ancestor(
        of: find.byType(CompactHtmlPreview),
        matching: find.byType(InkWell),
      );
      expect(previewInk, findsOneWidget);
      return tester.getSize(previewInk).width;
    }

    final shortWidth = await pumpPreview('短');
    final longWidth = await pumpPreview('这是一条足够长、会占据多行的跟评内容，用来验证容器不会随文字长度变化。');

    expect(shortWidth, longWidth);
    expect(shortWidth, 320);
  });

  test('child comment panel uses the safe-area width', () {
    final constraints = childCommentPanelConstraints(
      const MediaQueryData(
        size: Size(400, 800),
        padding: EdgeInsets.only(left: 12, right: 8, top: 24, bottom: 16),
      ),
    );

    expect(constraints.minWidth, 380);
    expect(constraints.maxWidth, 380);
    expect(constraints.maxHeight, 680);
  });
}
