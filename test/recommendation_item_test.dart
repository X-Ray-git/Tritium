import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/models/recommendation_item.dart';

void main() {
  test('extracts stable answer identity and verified feedback target', () {
    final descriptor = RecommendationItemDescriptor.fromRaw({
      'target': {
        'type': 'answer',
        'id': 42,
        'question': {'id': 7, 'title': 'Question'},
      },
    });

    expect(descriptor?.stableKey, 'answer:42');
    expect(descriptor?.feedbackTarget?.payload('t'), ['t', 'a', '42']);
  });

  test('extracts article identity from a serialized brief', () {
    final descriptor = RecommendationItemDescriptor.fromRaw({
      'brief': jsonEncode({
        'target': {'type': 'article', 'id': '81'},
      }),
    });

    expect(descriptor?.stableKey, 'article:81');
    expect(descriptor?.feedbackTarget?.payload('r'), ['r', 'p', '81']);
  });

  test(
    'uses a navigation URL without guessing feedback for unsupported type',
    () {
      final descriptor = RecommendationItemDescriptor.fromRaw({
        'type': 'feed',
        'id': 'envelope-id',
        'common_card': {
          'action': {'intent_url': 'zhihu://pin/123'},
        },
      });

      expect(descriptor?.stableKey, 'pin:123');
      expect(descriptor?.feedbackTarget, isNull);
    },
  );

  test('session filter removes page and later session duplicates', () {
    final filter = RecommendationSessionFilter();
    Map<String, dynamic> answer(String id) => {
      'target': {'type': 'answer', 'id': id},
    };

    final first = filter.accept([answer('1'), answer('1'), answer('2')]);
    final second = filter.accept([answer('2'), answer('3')]);

    expect(
      first.map(RecommendationItemDescriptor.fromRaw).map((e) => e?.stableKey),
      ['answer:1', 'answer:2'],
    );
    expect(
      second.map(RecommendationItemDescriptor.fromRaw).map((e) => e?.stableKey),
      ['answer:3'],
    );
    expect(filter.seenCount, 3);
  });
}
