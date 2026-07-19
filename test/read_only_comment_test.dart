import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/common/theme/theme_utils.dart';
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
}
