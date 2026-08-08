import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../http/comment_http.dart';
import '../../http/init.dart';
import '../../models/common/paging_info.dart';
import '../../utils/comment_auto_load.dart';
import '../../utils/storage.dart';
import 'app_chrome.dart';
import 'feedback_toast.dart';
import 'unified_comment_item.dart';

typedef CommentPageLoader =
    Future<LoadingState<Map<String, dynamic>>> Function({
      required String resourceId,
      required String resourceType,
      required String orderBy,
      String? nextUrl,
    });

/// 内联评论组件
///
/// 用于在回答/文章/想法详情页中嵌入显示评论列表
/// 参考 PiliPlus 的 dynamics_detail 设计
class InlineCommentWidget extends StatefulWidget {
  /// 资源 ID（回答/文章/想法 ID）
  final String resourceId;

  /// 资源类型：answers, articles, pins
  final String resourceType;

  /// 初始显示的评论数量
  final int initialCount;

  /// 是否显示标题
  final bool showHeader;

  /// 仅用于替换数据来源或测试；生产环境默认调用 [CommentHttp.getRootComments]。
  final CommentPageLoader? pageLoader;

  const InlineCommentWidget({
    super.key,
    required this.resourceId,
    required this.resourceType,
    this.initialCount = 10,
    this.showHeader = true,
    this.pageLoader,
  });

  @override
  State<InlineCommentWidget> createState() => _InlineCommentWidgetState();
}

class _InlineCommentWidgetState extends State<InlineCommentWidget>
    with AutomaticKeepAliveClientMixin {
  final List<dynamic> _comments = [];
  String? _nextUrl;
  int _totalCount = 0;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMsg = '';
  late String _orderBy;
  int _loadGeneration = 0;

  /// 加载更多失败时保留错误信息，尾部展示可点击重试；成功后清空。
  String? _loadMoreError;

  /// 哨兵：用于判断“加载更多”入口是否已进入预加载范围。
  final GlobalKey _loadMoreKey = GlobalKey();
  final Set<String> _consumedPageUrls = {};
  ScrollPosition? _scrollPosition;
  bool _autoLoadArmed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _orderBy = Pref.defaultCommentSort;
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPosition = Scrollable.maybeOf(
      context,
      axis: Axis.vertical,
    )?.position;
    if (identical(nextPosition, _scrollPosition)) return;
    _scrollPosition?.removeListener(_handleParentScroll);
    _scrollPosition = nextPosition;
    _scrollPosition?.addListener(_handleParentScroll);
    _scheduleAutoLoadCheck();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _scrollPosition?.removeListener(_handleParentScroll);
    super.dispose();
  }

  Future<void> _loadData({bool loadMore = false}) async {
    if (_isLoading && loadMore) return;
    final requestedNextUrl = loadMore ? _nextUrl : null;
    if (loadMore && requestedNextUrl == null) return;
    if (requestedNextUrl != null &&
        _consumedPageUrls.contains(requestedNextUrl)) {
      setState(() => _nextUrl = null);
      return;
    }
    final generation = loadMore ? _loadGeneration : ++_loadGeneration;

    setState(() {
      _isLoading = true;
      _hasError = false;
      if (!loadMore) _loadMoreError = null;
    });

    final loader = widget.pageLoader ?? CommentHttp.getRootComments;
    final result = await loader(
      resourceId: widget.resourceId,
      resourceType: widget.resourceType,
      orderBy: _orderBy,
      nextUrl: requestedNextUrl,
    );

    if (!mounted || generation != _loadGeneration) return;

    if (result is Success<Map<String, dynamic>>) {
      final data = result.response;
      final paging = PagingInfo.fromJson(data['paging']);
      final counts = data['counts'] as Map<String, dynamic>?;
      final commonCounts = data['common_counts'] as Map<String, dynamic>?;

      if (!loadMore) {
        _totalCount =
            counts?['total_counts'] ?? commonCounts?['total_counts'] ?? 0;
        _comments.clear();
        _consumedPageUrls.clear();
      } else {
        _consumedPageUrls.add(requestedNextUrl!);
      }

      final List<dynamic> newComments = data['data'] ?? [];
      final addedCount = _appendUniqueComments(newComments);
      final candidateNextUrl = paging.nextUrl;
      final madeProgress = !loadMore || addedCount > 0;
      _nextUrl =
          madeProgress &&
              candidateNextUrl != null &&
              candidateNextUrl != requestedNextUrl &&
              !_consumedPageUrls.contains(candidateNextUrl)
          ? candidateNextUrl
          : null;

      setState(() {
        _isLoading = false;
        _loadMoreError = null;
      });
    } else if (result is Error<Map<String, dynamic>>) {
      final message = result.errMsg;
      setState(() {
        _isLoading = false;
        _hasError = !loadMore && _comments.isEmpty;
        _errorMsg = message;
        if (loadMore) _loadMoreError = message;
      });
      if (!loadMore && _comments.isNotEmpty) {
        TritiumFeedback.error('评论加载失败', message);
      }
    }
    if (result is Success<Map<String, dynamic>>) {
      _scheduleAutoLoadCheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 评论区标题
        if (widget.showHeader)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: 8,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '评论',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_totalCount',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                // 排序按钮
                TextButton.icon(
                  onPressed: _showSortOptions,
                  icon: Icon(
                    Icons.sort_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  label: Text(
                    _orderBy == 'score' ? '按热度' : '按时间',
                    style: TextStyle(fontSize: 13, color: colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),

        // 评论列表
        if (_hasError)
          _buildErrorWidget()
        else if (_isLoading && _comments.isEmpty)
          _buildLoadingWidget()
        else if (_comments.isEmpty)
          _buildEmptyWidget()
        else
          ..._buildCommentList(),

        // 加载更多（自动加载为主，保留可点击兜底）
        if (_nextUrl != null ||
            _loadMoreError != null ||
            _isLoading && _comments.isNotEmpty)
          _buildLoadMoreTail(),

        // 底部间距
        const SizedBox(height: 20),
      ],
    );
  }

  void _handleParentScroll() => _maybeAutoLoad();

  void _scheduleAutoLoadCheck() {
    if (!mounted || _autoLoadArmed) return;
    _autoLoadArmed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLoadArmed = false;
      if (mounted) _maybeAutoLoad();
    });
  }

  /// 评估“加载更多”哨兵是否进入预加载范围，是则自动拉取下一页。
  void _maybeAutoLoad() {
    if (_isLoading || _nextUrl == null || _loadMoreError != null) return;
    final position = _scrollPosition;
    if (!mounted ||
        position == null ||
        !position.hasPixels ||
        !position.hasViewportDimension) {
      return;
    }
    final sentinelScrollOffset = _sentinelScrollOffset();
    if (sentinelScrollOffset == null) return;
    if (!shouldAutoLoadMore(
      sentinelScrollOffset: sentinelScrollOffset,
      scrollOffset: position.pixels,
      viewportDimension: position.viewportDimension,
    )) {
      return;
    }
    _loadData(loadMore: true);
  }

  /// 计算让哨兵对齐视口顶部所需的绝对滚动位置。
  double? _sentinelScrollOffset() {
    final ctx = _loadMoreKey.currentContext;
    if (ctx == null) return null;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        !renderObject.attached) {
      return null;
    }
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) return null;
    return viewport.getOffsetToReveal(renderObject, 0.0).offset;
  }

  int _appendUniqueComments(List<dynamic> newComments) {
    final knownIds = _comments.map(_commentId).whereType<String>().toSet();
    var addedCount = 0;
    for (final comment in newComments) {
      final id = _commentId(comment);
      if (id != null && !knownIds.add(id)) continue;
      _comments.add(comment);
      addedCount++;
    }
    return addedCount;
  }

  String? _commentId(dynamic comment) {
    if (comment is! Map) return null;
    final value = comment['id']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  void _showSortOptions() {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => TritiumGlassSheet(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('按热度排序'),
                trailing: _orderBy == 'score'
                    ? Icon(Icons.check, color: colorScheme.primary)
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (_orderBy != 'score') {
                    _orderBy = 'score';
                    _loadData();
                  }
                },
              ),
              ListTile(
                title: const Text('按时间排序'),
                trailing: _orderBy == 'ts'
                    ? Icon(Icons.check, color: colorScheme.primary)
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (_orderBy != 'ts') {
                    _orderBy = 'ts';
                    _loadData();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Text(_errorMsg, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadData, child: const Text('重试')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text('暂无评论', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  List<Widget> _buildCommentList() {
    return _comments.map((comment) {
      return UnifiedCommentItem(
        comment: comment,
        resourceId: widget.resourceId,
        resourceType: widget.resourceType,
      );
    }).toList();
  }

  /// 尾部加载入口：自动加载触发时显示 loading；失败后退化为可点击重试；
  /// 正常空闲态保留"查看更多评论"作为兜底与可访问入口，并作为自动加载的哨兵。
  Widget _buildLoadMoreTail() {
    final colorScheme = Theme.of(context).colorScheme;

    // 加载更多失败：展示可点击重试。
    if (_loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: InkWell(
          onTap: () {
            setState(() => _loadMoreError = null);
            _loadData(loadMore: true);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '加载失败，点击重试',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 正在加载下一页：展示转圈。
    if (_isLoading && _comments.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      );
    }

    // 空闲态：既是兜底可点击入口，也是自动加载的几何哨兵。
    return Padding(
      key: _loadMoreKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _loadData(loadMore: true),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '查看更多评论',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
