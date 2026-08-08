import '../../http/init.dart';
import '../../models/common/paging_info.dart';

/// 回答列表分页加载器；生产环境由 [QuestionHttp.getQuestionAnswers] 提供。
typedef AnswerPageLoader =
    Future<LoadingState<Map<String, dynamic>>> Function({
      required String questionId,
      required String sortBy,
      String? nextUrl,
    });

/// 回答序列种子/状态模型。
///
/// 从问题页进入时接收已有 ID 列表、下一页游标与排序方式，之后由回答页接管
/// 分页；从推荐页等只传入单个回答的入口进入时，先获取所属问题第一页并保留
/// 当前回答。列表按 ID 去重，重复 cursor、空页与 `is_end` 都视为没有进展，
/// 防止请求循环。追加数据不改变既有条目的索引，因此页面不会跳页。
class AnswerPager {
  String? questionId;
  final List<String> answerIds;
  final String sortBy;
  final AnswerPageLoader _loader;

  String? nextUrl;
  bool isEnd;
  String? lastError;
  final Set<String> _consumedCursors = {};
  bool _loading = false;
  bool _hasLoadedFirstPage = false;
  bool _firstPageSucceeded = false;
  int _generation = 0;
  String? _lastRequestedCursor;

  AnswerPager({
    required this.questionId,
    required List<String> answerIds,
    required this.sortBy,
    required AnswerPageLoader loader,
    String? nextUrl,
    bool isEnd = false,
  }) : answerIds = _deduplicate(answerIds),
       _loader = loader,
       nextUrl = nextUrl,
       isEnd = nextUrl != null ? false : isEnd;

  bool get isLoading => _loading;
  bool get hasMore => !isEnd && !_loading && nextUrl != null;
  bool get hasError => lastError != null;

  static List<String> _deduplicate(List<String> ids) {
    final seen = <String>{};
    return ids
        .where((id) => id.isNotEmpty && seen.add(id))
        .toList(growable: true);
  }

  /// 单回答入口需要先补齐问题第一页回答列表。
  bool get needsFirstPageLoad =>
      !_hasLoadedFirstPage &&
      questionId != null &&
      answerIds.length <= 1 &&
      nextUrl == null &&
      !isEnd;

  /// 加载所属问题第一页；当前回答即使不在第一页也保留在列表最前。
  Future<void> loadFirstPage(String currentAnswerId) async {
    if (_loading || _hasLoadedFirstPage || questionId == null) return;
    final generation = ++_generation;
    _loading = true;
    lastError = null;

    final result = await _loader(questionId: questionId!, sortBy: sortBy);
    if (generation != _generation) return;

    _loading = false;
    _hasLoadedFirstPage = true;
    if (result is Success<Map<String, dynamic>>) {
      _mergePage(result.response, isFirstPage: true);
      _firstPageSucceeded = true;
    } else if (result is Error<Map<String, dynamic>>) {
      lastError = result.errMsg;
    }
    _keepCurrentAnswer(currentAnswerId);
  }

  /// 加载下一页。只有服务器明确 `is_end` 或没有有效游标时才真正停止。
  Future<void> loadNextPage() async {
    final cursor = nextUrl;
    if (_loading || cursor == null || isEnd) return;
    if (_consumedCursors.contains(cursor)) {
      // 重复 cursor：视为无进展并停止自动请求。
      nextUrl = null;
      return;
    }
    if (questionId == null) return;
    _lastRequestedCursor = cursor;
    final generation = ++_generation;
    _loading = true;
    lastError = null;

    final result = await _loader(
      questionId: questionId!,
      sortBy: sortBy,
      nextUrl: cursor,
    );
    if (generation != _generation) return;

    _loading = false;
    if (result is Success<Map<String, dynamic>>) {
      _consumedCursors.add(cursor);
      _mergePage(result.response, isFirstPage: false);
    } else if (result is Error<Map<String, dynamic>>) {
      lastError = result.errMsg;
    }
  }

  void _mergePage(Map<String, dynamic> data, {required bool isFirstPage}) {
    final paging = PagingInfo.fromJson(data['paging']);
    final items =
        (data['data'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
        [];
    final ids = items
        .map((item) {
          final target = (item['target'] as Map<String, dynamic>?) ?? item;
          return target['id']?.toString();
        })
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    var madeProgress = ids.isNotEmpty;
    if (isFirstPage) {
      answerIds
        ..clear()
        ..addAll(_deduplicate(ids));
    } else {
      final newIds = ids
          .where((id) => !answerIds.contains(id))
          .toList(growable: false);
      madeProgress = newIds.isNotEmpty;
      answerIds.addAll(newIds);
    }

    final candidateNextUrl = paging.isEnd ? null : paging.nextUrl;
    // 空页、重复 cursor 或 is_end 时停止，避免请求循环。
    nextUrl =
        madeProgress &&
            candidateNextUrl != null &&
            candidateNextUrl != _lastRequestedCursor &&
            !_consumedCursors.contains(candidateNextUrl)
        ? candidateNextUrl
        : null;
    if (paging.isEnd) isEnd = true;
    _lastRequestedCursor = null;
  }

  /// 当前回答不在已加载列表时插到最前，保持阅读入口可用。
  void _keepCurrentAnswer(String currentAnswerId) {
    if (currentAnswerId.isEmpty) return;
    answerIds.remove(currentAnswerId);
    answerIds.insert(0, currentAnswerId);
  }

  /// 距离列表末尾约 2 项时预取下一页。
  bool shouldPrefetch(int currentIndex) {
    if (currentIndex < 0 || currentIndex >= answerIds.length) return false;
    return currentIndex >= answerIds.length - 2 && hasMore;
  }

  /// 分页失败后的可重试入口；首屏补齐失败时重试首屏。
  Future<void> retry(String currentAnswerId) async {
    if (_loading) return;
    if (!_firstPageSucceeded && answerIds.length <= 1 && questionId != null) {
      _hasLoadedFirstPage = false;
      _firstPageSucceeded = false;
      await loadFirstPage(currentAnswerId);
      return;
    }
    if (lastError != null) {
      lastError = null;
      await loadNextPage();
    }
  }

  /// 清除错误状态，用于点击重试前重置占位页。
  void clearError() {
    lastError = null;
  }

  void dispose() {
    _generation++;
  }
}
