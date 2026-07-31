import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/models/recommendation_item.dart';
import 'package:tritium/services/recommendation_feedback_service.dart';

void main() {
  RecommendationFeedbackTarget target(int id) =>
      RecommendationFeedbackTarget(type: 'a', id: '$id');

  test('batches five settled touch targets', () async {
    final posts = <List<List<String>>>[];
    final service = RecommendationFeedbackService(
      poster: (targets) async {
        posts.add(targets);
        return true;
      },
    );

    await service.reportTouched([target(1), target(2), target(3), target(4)]);
    expect(posts, isEmpty);

    await service.reportTouched([target(5)]);
    expect(posts, [
      [
        ['t', 'a', '1'],
        ['t', 'a', '2'],
        ['t', 'a', '3'],
        ['t', 'a', '4'],
        ['t', 'a', '5'],
      ],
    ]);
  });

  test('a read event immediately flushes pending touches', () async {
    final posts = <List<List<String>>>[];
    final service = RecommendationFeedbackService(
      poster: (targets) async {
        posts.add(targets);
        return true;
      },
    );

    await service.reportTouched([target(1)]);
    await service.reportRead(target(2));

    expect(posts.single, [
      ['t', 'a', '1'],
      ['r', 'a', '2'],
    ]);
  });

  test('a read arriving during a request is flushed afterwards', () async {
    final firstPostStarted = Completer<void>();
    final releaseFirstPost = Completer<void>();
    final posts = <List<List<String>>>[];
    final service = RecommendationFeedbackService(
      poster: (targets) async {
        posts.add(targets);
        if (posts.length == 1) {
          firstPostStarted.complete();
          await releaseFirstPost.future;
        }
        return true;
      },
    );

    final firstRead = service.reportRead(target(1));
    await firstPostStarted.future;
    final secondRead = service.reportRead(target(2));
    releaseFirstPost.complete();
    await Future.wait([firstRead, secondRead]);

    expect(posts, [
      [
        ['r', 'a', '1'],
      ],
      [
        ['r', 'a', '2'],
      ],
    ]);
  });
}
