import 'package:flutter/material.dart';

import 'tritium_refresh_indicator_core.dart' as custom_refresh;

/// 与 Auto Folo 共用同一套下拉刷新状态机和 AppBar 遮挡关系。
class TritiumRefreshIndicator extends StatefulWidget {
  final Widget child;
  final custom_refresh.RefreshCallback onRefresh;

  const TritiumRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  State<TritiumRefreshIndicator> createState() =>
      _TritiumRefreshIndicatorState();
}

class _TritiumRefreshIndicatorState extends State<TritiumRefreshIndicator> {
  final _refreshKey = GlobalKey<custom_refresh.RefreshIndicatorState>();

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: _RefreshScrollBehavior(_refreshKey),
      child: custom_refresh.RefreshIndicator(
        key: _refreshKey,
        edgeOffset: MediaQuery.paddingOf(context).top,
        displacement: 20,
        onRefresh: widget.onRefresh,
        child: widget.child,
      ),
    );
  }
}

class _RefreshScrollBehavior extends MaterialScrollBehavior {
  final GlobalKey<custom_refresh.RefreshIndicatorState> refreshKey;

  const _RefreshScrollBehavior(this.refreshKey);

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return _RefreshAwareScrollPhysics(
      refreshKey: refreshKey,
      parent: super.getScrollPhysics(context),
    );
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

/// 直接使用刷新状态机的 dragOffset；不再另行估算手势距离。
class _RefreshAwareScrollPhysics extends AlwaysScrollableScrollPhysics {
  final GlobalKey<custom_refresh.RefreshIndicatorState> refreshKey;

  const _RefreshAwareScrollPhysics({required this.refreshKey, super.parent});

  @override
  _RefreshAwareScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _RefreshAwareScrollPhysics(
      refreshKey: refreshKey,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final parentResult = super.applyBoundaryConditions(position, value);
    final state = refreshKey.currentState;
    if (state == null) return parentResult;

    final status = state.status;
    final isDragging =
        status == custom_refresh.RefreshIndicatorStatus.drag ||
        status == custom_refresh.RefreshIndicatorStatus.armed;
    if (isDragging &&
        (state.dragOffset ?? 0) > 0 &&
        value > position.pixels &&
        position.pixels <= position.minScrollExtent) {
      return value - position.pixels;
    }
    return parentResult;
  }
}
