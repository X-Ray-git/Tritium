import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/http/content_http.dart';
import 'package:tritium/pages/article/article_page.dart';
import 'package:tritium/pages/widgets/hot_card.dart';
import 'package:tritium/utils/count_format.dart';

void main() {
  group('parseCount', () {
    test('accepts ints, nums and valid strings', () {
      expect(parseCount(123), 123);
      expect(parseCount(123.9), 123);
      expect(parseCount('456'), 456);
      expect(parseCount(' 78 '), 78);
    });

    test('returns null for missing or invalid values', () {
      expect(parseCount(null), isNull);
      expect(parseCount(''), isNull);
      expect(parseCount('abc'), isNull);
      expect(parseCount('12.5万'), isNull);
      expect(parseCount({}), isNull);
      expect(parseCount(double.nan), isNull);
      expect(parseCount(double.infinity), isNull);
      expect(parseCount(-1), isNull);
      expect(parseCount('-2'), isNull);
    });
  });

  group('firstValidCount', () {
    test('prefers the primary value', () {
      expect(firstValidCount(100, 200), 100);
    });

    test('falls back to the secondary value', () {
      expect(firstValidCount(null, 200), 200);
      expect(firstValidCount('bad', '200'), 200);
    });

    test('returns null when both are invalid', () {
      expect(firstValidCount(null, null), isNull);
      expect(firstValidCount('bad', ''), isNull);
    });
  });

  group('formatCount', () {
    test('unknown values are displayed as a dash, never as zero', () {
      expect(formatCount(null), '—');
      expect(formatCount('bad'), '—');
    });

    test('formats small counts directly', () {
      expect(formatCount(0), '0');
      expect(formatCount(999), '999');
    });

    test('formats thousands and ten-thousands', () {
      expect(formatCount(1234), '1.2k');
      expect(formatCount(12000), '1.2万');
      expect(formatCount(123456), '12.3万');
    });
  });

  group('HotCard statistics', () {
    setUp(() {
      // 预置问题缓存，避免 HotCard 触发预加载网络请求。
      QuestionHttp.cache.clear();
      QuestionHttp.cache['1'] = {'title': '标题', 'visit_count': 99};
    });

    tearDown(() => QuestionHttp.cache.clear());

    Widget wrap(Map<String, dynamic> data) {
      return MaterialApp(
        home: Scaffold(body: HotCard(data: data, index: 0)),
      );
    }

    testWidgets('shows heat from metrics_area and answers count', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap({
          'target': {
            'id': '1',
            'title': '标题',
            'metrics_area': {'text': '1234 万热度'},
            'answer_count': 42,
          },
        }),
      );

      expect(find.byIcon(Icons.local_fire_department_outlined), findsOneWidget);
      expect(find.text('1234 万'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      final fireIcon = tester.widget<Icon>(
        find.byIcon(Icons.local_fire_department_outlined),
      );
      final answerIcon = tester.widget<Icon>(
        find.byIcon(Icons.question_answer_outlined),
      );
      final heatLabel = tester.widget<Text>(find.text('1234 万'));
      final answerLabel = tester.widget<Text>(find.text('42'));
      expect(fireIcon.color, answerIcon.color);
      expect(heatLabel.style?.color, answerLabel.style?.color);
      // 眼睛图标不再绑定到 follower_count 冒充浏览量。
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    });

    testWidgets('falls back to detail_text heat', (tester) async {
      await tester.pumpWidget(
        wrap({
          'target': {'id': '1', 'title': '标题', 'detail_text': '热榜第 5'},
        }),
      );

      expect(find.text('热榜第 5'), findsOneWidget);
    });

    testWidgets('keeps the real top-level hot-list detail_text shape', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap({
          'detail_text': '987 万热度',
          'target': {'id': '1', 'title': '标题'},
        }),
      );

      expect(find.text('987 万'), findsOneWidget);
    });

    testWidgets('unknown answer count is a dash, not a fake zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap({
          'target': {
            'id': '1',
            'title': '标题',
            'metrics_area': {'text': '热度'},
          },
        }),
      );

      expect(find.text('—'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('shows the new/hot label chip', (tester) async {
      await tester.pumpWidget(
        wrap({
          'target': {
            'id': '1',
            'title': '标题',
            'label_area': {'text': '新'},
            'metrics_area': {'text': '热度'},
          },
        }),
      );

      expect(find.text('新'), findsOneWidget);
    });

    testWidgets('supports a top-level card_label', (tester) async {
      await tester.pumpWidget(
        wrap({
          'card_label': {'text': '热'},
          'target': {'id': '1', 'title': '标题'},
        }),
      );

      expect(find.text('热'), findsOneWidget);
    });
  });

  group('article cover geometry', () {
    test('uses width divided by height for source dimensions', () {
      expect(
        articleCoverAspectRatio(sourceWidth: 1600, sourceHeight: 900),
        closeTo(16 / 9, 0.0001),
      );
      expect(
        articleCoverAspectRatio(sourceWidth: 900, sourceHeight: 1600),
        closeTo(9 / 16, 0.0001),
      );
    });

    test('rejects invalid dimensions and uses a stable fallback', () {
      expect(parseDouble(double.nan), isNull);
      expect(parseDouble(double.infinity), isNull);
      expect(parseDouble(-1), isNull);
      expect(articleCoverAspectRatio(), closeTo(5 / 3, 0.0001));
    });
  });
}
