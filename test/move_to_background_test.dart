import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/utils/move_to_background.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('io.github.xraygit.tritium/move_to_background');

  test('requests Android to move the task to the background', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await MoveToBackground.moveTaskToBack();

    expect(receivedCall, isNotNull);
    expect(receivedCall!.method, 'moveTaskToBack');
  });
}
