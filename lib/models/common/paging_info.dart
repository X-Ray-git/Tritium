/// Normalized pagination metadata shared by list modules.
///
/// Zhihu endpoints are not fully consistent when a page has no successor:
/// some omit `paging`, some set `is_end`, and others return an empty `next`.
/// Keeping that normalization here prevents list screens from retrying the
/// same page forever.
class PagingInfo {
  final bool isEnd;
  final String? nextUrl;

  const PagingInfo({required this.isEnd, this.nextUrl});

  const PagingInfo.end() : isEnd = true, nextUrl = null;

  bool get hasNext => !isEnd && nextUrl != null;

  factory PagingInfo.fromJson(dynamic value) {
    if (value is! Map) return const PagingInfo.end();

    final rawNext = value['next']?.toString().trim();
    final nextUrl = rawNext == null || rawNext.isEmpty ? null : rawNext;
    final isEnd = value['is_end'] == true || nextUrl == null;

    return PagingInfo(isEnd: isEnd, nextUrl: isEnd ? null : nextUrl);
  }
}
