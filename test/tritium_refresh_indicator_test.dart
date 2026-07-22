import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/common/widgets/tritium_refresh_indicator.dart';
import 'package:tritium/common/widgets/tritium_refresh_indicator_core.dart'
    as custom_refresh;

void main() {
  testWidgets('reversing a pull gesture keeps the list at its top edge', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 600),
            padding: EdgeInsets.only(top: 24),
          ),
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(toolbarHeight: 48),
            body: TritiumRefreshIndicator(
              onRefresh: () async {},
              child: ListView.builder(
                controller: controller,
                itemCount: 30,
                itemBuilder: (context, index) =>
                    SizedBox(height: 56, child: Text('item $index')),
              ),
            ),
          ),
        ),
      ),
    );

    final indicator = tester.widget<custom_refresh.RefreshIndicator>(
      find.byType(custom_refresh.RefreshIndicator),
    );
    expect(indicator.edgeOffset, tester.getBottomLeft(find.byType(AppBar)).dy);
    expect(indicator.displacement, 20);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('item 2')),
    );
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    var refreshState = tester.state<custom_refresh.RefreshIndicatorState>(
      find.byType(custom_refresh.RefreshIndicator),
    );
    expect(
      refreshState.status,
      anyOf(
        custom_refresh.RefreshIndicatorStatus.drag,
        custom_refresh.RefreshIndicatorStatus.armed,
      ),
    );
    expect(refreshState.dragOffset, greaterThan(0));

    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();

    expect(controller.offset, 0);
    refreshState = tester.state<custom_refresh.RefreshIndicatorState>(
      find.byType(custom_refresh.RefreshIndicator),
    );
    expect(refreshState.dragOffset, greaterThan(0));

    // 指示器完全回到 AppBar 后，同一手势继续上推应恢复正常滚动。
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(controller.offset, 0);
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(controller.offset, greaterThan(0));
    await gesture.up();
  });
}
