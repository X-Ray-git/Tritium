/// 评论区是否已进入视口附近。
///
/// 锚点位置用于覆盖短正文首次布局后没有滚动通知的情况；滚动余量用于长正文滚动。
bool shouldPreloadComments({
  double? anchorTop,
  required double viewportHeight,
  double? extentAfter,
  double preloadExtent = 720,
}) {
  if (anchorTop != null && anchorTop <= viewportHeight + preloadExtent) {
    return true;
  }
  return extentAfter != null && extentAfter <= preloadExtent;
}
