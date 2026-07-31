/// 评论区“加载更多”哨兵是否已进入预加载范围。
///
/// [sentinelScrollOffset] 与 [scrollOffset] 必须位于同一个滚动坐标系中。
/// 哨兵到当前视口下边缘的距离不大于 [preloadExtent] 时触发下一页。
bool shouldAutoLoadMore({
  required double sentinelScrollOffset,
  required double scrollOffset,
  required double viewportDimension,
  double preloadExtent = 720,
}) {
  if (!sentinelScrollOffset.isFinite ||
      !scrollOffset.isFinite ||
      !viewportDimension.isFinite ||
      !preloadExtent.isFinite ||
      viewportDimension <= 0 ||
      preloadExtent < 0) {
    return false;
  }
  final preloadBoundary = scrollOffset + viewportDimension + preloadExtent;
  return sentinelScrollOffset <= preloadBoundary;
}
