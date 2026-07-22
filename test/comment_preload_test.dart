import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/utils/comment_preload.dart';

void main() {
  test('short content preloads comments without a scroll notification', () {
    expect(shouldPreloadComments(anchorTop: 620, viewportHeight: 700), isTrue);
  });

  test('long content waits until its scroll remainder enters the range', () {
    expect(
      shouldPreloadComments(
        anchorTop: 2400,
        viewportHeight: 700,
        extentAfter: 1600,
      ),
      isFalse,
    );
    expect(
      shouldPreloadComments(
        anchorTop: 1500,
        viewportHeight: 700,
        extentAfter: 600,
      ),
      isTrue,
    );
  });
}
