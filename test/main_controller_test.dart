import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/pages/main/main_controller.dart';

void main() {
  test('main controller switches tabs and reselects content to scroll up', () {
    final controller = MainController();
    var scrollRequests = 0;
    controller.scrollToTopCallback = () => scrollRequests++;

    controller.changeIndex(1);
    expect(controller.currentIndex.value, 1);
    expect(scrollRequests, 0);

    controller.changeIndex(0);
    expect(controller.currentIndex.value, 0);
    expect(scrollRequests, 0);

    controller.changeIndex(0);
    expect(scrollRequests, 1);
  });
}
