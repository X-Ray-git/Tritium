import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';

import '../../http/content_http.dart';
import '../../http/init.dart';
import '../../common/widgets/loading_widget.dart';
import '../../common/widgets/error_widget.dart' as custom;
import '../../router/app_pages.dart';
import '../../common/widgets/html/chunked_html_sliver.dart';
import '../../common/widgets/html/html_chunker.dart';
import '../../utils/count_format.dart';
import '../../utils/storage.dart';
import '../../common/widgets/inline_comment_widget.dart';
import '../../common/widgets/blur_container.dart';
import '../../common/widgets/app_chrome.dart';
import '../../utils/comment_preload.dart';
import '../../common/widgets/content_actions.dart';
import '../../common/widgets/reading_progress.dart';
import '../../services/reading_history_service.dart';
import 'answer_pager.dart';

/// 回答详情页 (容器)
class AnswerPage extends StatefulWidget {
  final String? questionId;
  final String? answerId;
  final List<String>? answerIds;
  final int initialIndex;

  const AnswerPage({
    super.key,
    this.questionId,
    this.answerId,
    this.answerIds,
    this.initialIndex = 0,
  });

  @override
  State<AnswerPage> createState() => _AnswerPageState();
}

class _AnswerPageState extends State<AnswerPage> {
  late final AnswerPager _pager;
  String? _initialAnswerId;

  late final PageController _pageController;
  final Map<String, GlobalKey> _commentKeys = {};
  final Map<String, GlobalKey<_AnswerSinglePageState>> _answerPageKeys = {};
  final Set<String> _contentReadyAnswerIds = {};
  String? _pendingCommentAnswerId;

  int _currentIndex = 0;
  bool _hasPendingPageTransition = false;

  // AppBar 标题可见性（当内容区域的标题滚出视图时显示）
  final ValueNotifier<bool> _showTitleNotifier = ValueNotifier(false);
  late final ValueNotifier<String> _questionTitleNotifier;
  late final ValueNotifier<dynamic> _voteupCountNotifier;
  late final ValueNotifier<dynamic> _commentCountNotifier;
  late final ValueNotifier<int> _settledPageIndexNotifier;
  final ValueNotifier<double> _readingProgressNotifier = ValueNotifier(0);
  final ValueNotifier<bool> _readingSeekableNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments as Map<String, dynamic>?;

    // 优先使用 Constructor 参数，其次使用 Get.arguments
    final questionId = widget.questionId ?? arguments?['questionId'];
    _initialAnswerId = widget.answerId ?? arguments?['answerId'];

    final passedIds =
        widget.answerIds ??
        (arguments?['answerIds'] as List?)
            ?.map((value) => value?.toString())
            .whereType<String>()
            .toList();

    final sortBy = (arguments?['sortBy'] as String?) ?? Pref.defaultAnswerSort;
    final nextUrl = (arguments?['nextUrl'] as String?)?.trim().nullIfEmpty;
    final isEnd = arguments?['isEnd'] == true;

    final seedIds = passedIds != null && passedIds.isNotEmpty
        ? passedIds
        : <String>[?_initialAnswerId];

    _pager = AnswerPager(
      questionId: questionId?.toString(),
      answerIds: seedIds,
      sortBy: sortBy,
      nextUrl: nextUrl,
      isEnd: isEnd,
      loader:
          ({
            required String questionId,
            required String sortBy,
            String? nextUrl,
          }) => QuestionHttp.getQuestionAnswers(
            questionId: questionId,
            sortBy: sortBy,
            nextUrl: nextUrl,
          ),
    );

    // 计算初始索引
    _currentIndex = 0;
    if (_initialAnswerId != null) {
      final index = _pager.answerIds.indexOf(_initialAnswerId!);
      _currentIndex = index >= 0 ? index : 0;
    } else if (_pager.answerIds.isNotEmpty) {
      _currentIndex = widget.initialIndex.clamp(0, _pager.answerIds.length - 1);
    }
    _pageController = PageController(initialPage: _currentIndex);
    _questionTitleNotifier = ValueNotifier('回答详情');
    _voteupCountNotifier = ValueNotifier(null);
    _commentCountNotifier = ValueNotifier(null);
    _settledPageIndexNotifier = ValueNotifier(_currentIndex);
    _syncChromeForCurrentAnswer();

    // 从推荐页等只传入单个回答的入口进入时，补齐所属问题第一页。
    if (_pager.needsFirstPageLoad && _initialAnswerId != null) {
      _loadFirstPage(_initialAnswerId!);
    }

    // 初始预加载相邻回答
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _preloadNeighbors(_currentIndex);
    });
  }

  @override
  void dispose() {
    _pager.dispose();
    _pageController.dispose();
    _showTitleNotifier.dispose();
    _questionTitleNotifier.dispose();
    _voteupCountNotifier.dispose();
    _commentCountNotifier.dispose();
    _settledPageIndexNotifier.dispose();
    _readingProgressNotifier.dispose();
    _readingSeekableNotifier.dispose();
    super.dispose();
  }

  bool get _hasPlaceholderPage =>
      _pager.hasMore || _pager.isLoading || _pager.hasError;

  int get _pageCount => _pager.answerIds.length + (_hasPlaceholderPage ? 1 : 0);

  String? get _currentAnswerId {
    if (_currentIndex < _pager.answerIds.length) {
      return _pager.answerIds[_currentIndex];
    }
    return _pager.answerIds.isEmpty ? null : _pager.answerIds.last;
  }

  Future<void> _loadFirstPage(String currentAnswerId) async {
    await _pager.loadFirstPage(currentAnswerId);
    if (!mounted) return;
    setState(() {});
    if (_pager.answerIds.isNotEmpty) {
      final newIndex = _pager.answerIds.indexOf(currentAnswerId);
      final targetIndex = newIndex >= 0 ? newIndex : 0;
      _currentIndex = targetIndex;
      _settledPageIndexNotifier.value = targetIndex;
      _syncChromeForCurrentAnswer();
      _preloadNeighbors(targetIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(targetIndex);
        }
      });
    }
  }

  Future<void> _loadNextPage() async {
    await _pager.loadNextPage();
    if (!mounted) return;
    setState(() {});
    _preloadNeighbors(_currentIndex);
  }

  void _preloadNeighbors(int index) {
    final ids = _pager.answerIds;
    if (ids.isEmpty) return;

    if (index + 1 < ids.length) {
      _preloadAnswer(ids[index + 1]);
    }
    if (index - 1 >= 0) {
      _preloadAnswer(ids[index - 1]);
    }
  }

  void _preloadAnswer(String answerId) {
    final cached = AnswerHttp.cache[answerId];
    if (cached != null) {
      final content = cached['content'] ?? cached['detail'];
      if (content is String) HtmlChunker.preload(content);
      return;
    }
    AnswerHttp.getAnswer(answerId).then((result) {
      if (result is! Success<Map<String, dynamic>>) return;
      final content = result.response['content'] ?? result.response['detail'];
      if (content is String) HtmlChunker.preload(content);
    });
  }

  void _onPageChanged(int index) {
    if (index == _currentIndex) return;
    _currentIndex = index;
    _hasPendingPageTransition = true;
    // 触觉反馈只在跨过、松手将进入另一篇真实回答的阈值触发；
    // 加载占位页不能触发“已切换回答”的振动。
    if (index < _pager.answerIds.length && Pref.enableSwipeHaptics) {
      HapticFeedback.selectionClick();
    }
  }

  bool _handlePageScrollEnd(ScrollEndNotification notification) {
    if (notification.metrics.axis != Axis.horizontal ||
        !_hasPendingPageTransition) {
      return false;
    }
    _hasPendingPageTransition = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncChromeForCurrentAnswer();
      _settledPageIndexNotifier.value = _currentIndex;
      _preloadNeighbors(_currentIndex);
      _handlePaginationForIndex(_currentIndex);
    });
    return false;
  }

  void _handlePaginationForIndex(int index) {
    if (index >= _pager.answerIds.length) {
      // 滑入加载占位页：空闲时立即拉取下一页，失败保留可重试状态。
      if (!_pager.isLoading && !_pager.hasError) {
        _loadNextPage();
      }
      return;
    }
    // 距离列表末尾约 2 项时预取下一页。
    if (_pager.shouldPrefetch(index)) {
      _loadNextPage();
    }
  }

  void _syncChromeForCurrentAnswer([Map<String, dynamic>? loadedData]) {
    final answerId = _currentAnswerId;
    if (answerId == null) return;
    final data = loadedData ?? AnswerHttp.cache[answerId];
    _questionTitleNotifier.value =
        data?['question']?['title']?.toString() ?? '回答详情';
    // 正文尚未加载时不得短暂显示 0；使用 null（UI 显示 “—”）。
    _voteupCountNotifier.value = data?['voteup_count'];
    _commentCountNotifier.value = data?['comment_count'];
  }

  @override
  Widget build(BuildContext context) {
    if (_pager.answerIds.isEmpty && !_hasPlaceholderPage) {
      return const Scaffold(body: LoadingWidget(msg: '加载中...'));
    }

    return Scaffold(
      appBar: TritiumBlurAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: ValueListenableBuilder<String>(
          valueListenable: _questionTitleNotifier,
          builder: (context, questionTitle, child) =>
              ValueListenableBuilder<bool>(
                valueListenable: _showTitleNotifier,
                builder: (context, show, child) => AnimatedOpacity(
                  key: const Key('answer-collapsed-title'),
                  duration: const Duration(milliseconds: 200),
                  opacity: show ? 1.0 : 0.0,
                  child: Text(
                    questionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: _settledPageIndexNotifier,
            builder: (context, index, child) => ContentActionsMenu(
              title: _questionTitleNotifier.value,
              url: 'https://www.zhihu.com/answer/${_safeActionId(index)}',
            ),
          ),
        ],
      ),
      body: SelectionArea(
        child: TritiumReadingProgressOverlay(
          progress: _readingProgressNotifier,
          seekable: _readingSeekableNotifier,
          onSeek: (progress) {
            final answerId = _currentAnswerId;
            if (answerId == null) return;
            _answerPageKeys[answerId]?.currentState?.seekToProgress(progress);
          },
          child: NotificationListener<ScrollEndNotification>(
            onNotification: _handlePageScrollEnd,
            child: PageView.builder(
              controller: _pageController,
              allowImplicitScrolling: true,
              itemCount: _pageCount,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                // 加载占位页：预取下一页的过渡状态，不渲染回答正文。
                if (index >= _pager.answerIds.length) {
                  return _LoadingAnswerPlaceholder(
                    hasError: _pager.hasError,
                    isLoading: _pager.isLoading,
                    onRetry: () {
                      _pager.clearError();
                      setState(() {});
                      _loadNextPage();
                    },
                  );
                }
                final answerId = _pager.answerIds[index];
                final commentKey = _commentKeys.putIfAbsent(
                  answerId,
                  GlobalKey.new,
                );
                final answerPageKey = _answerPageKeys.putIfAbsent(
                  answerId,
                  GlobalKey<_AnswerSinglePageState>.new,
                );
                return _AnswerSinglePage(
                  key: answerPageKey,
                  answerId: answerId,
                  questionId: _pager.questionId,
                  commentsKey: commentKey,
                  pageIndex: index,
                  settledPageIndexListenable: _settledPageIndexNotifier,
                  initialData: AnswerHttp.cache.containsKey(answerId)
                      ? AnswerHttp.cache[answerId]
                      : null,
                  onQuestionIdLoaded: (qId) {
                    if (_pager.questionId == null && qId.isNotEmpty) {
                      _pager.questionId = qId;
                      if (_pager.needsFirstPageLoad) {
                        _loadFirstPage(answerId);
                      }
                    }
                  },
                  onDataLoaded: (data) {
                    if (!_hasPendingPageTransition &&
                        _currentAnswerId == answerId) {
                      _syncChromeForCurrentAnswer(data);
                    }
                  },
                  onTitleVisibilityChanged: (visible) {
                    if (_settledPageIndexNotifier.value == index &&
                        _showTitleNotifier.value != visible) {
                      _showTitleNotifier.value = visible;
                    }
                  },
                  onContentReady: () {
                    _contentReadyAnswerIds.add(answerId);
                    if (_pendingCommentAnswerId == answerId) {
                      _scrollToComments(answerId);
                    }
                  },
                  onReadingProgressChanged: (progress) {
                    if (_settledPageIndexNotifier.value == index) {
                      _readingProgressNotifier.value = progress;
                    }
                  },
                  onReadingSeekableChanged: (seekable) {
                    if (_settledPageIndexNotifier.value == index) {
                      _readingSeekableNotifier.value = seekable;
                    }
                  },
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: BlurBottomBar(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 8 + MediaQuery.of(context).padding.bottom,
        ),
        child: Row(
          children: [
            ValueListenableBuilder<dynamic>(
              valueListenable: _voteupCountNotifier,
              builder: (context, count, child) => _ActionButton(
                icon: Icons.thumb_up_outlined,
                label: formatCount(count),
              ),
            ),
            const SizedBox(width: 16),
            ValueListenableBuilder<dynamic>(
              valueListenable: _commentCountNotifier,
              builder: (context, count, child) => _ActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: formatCount(count),
                onTap: () {
                  final answerId = _currentAnswerId;
                  if (answerId != null) _scrollToComments(answerId);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _safeActionId(int index) {
    final ids = _pager.answerIds;
    if (ids.isEmpty) return '';
    return ids[index.clamp(0, ids.length - 1)];
  }

  void _scrollToComments(String answerId) {
    if (!_contentReadyAnswerIds.contains(answerId)) {
      _pendingCommentAnswerId = answerId;
      return;
    }
    final commentsContext = _commentKeys[answerId]?.currentContext;
    if (commentsContext == null) return;
    _pendingCommentAnswerId = null;
    Scrollable.ensureVisible(
      commentsContext,
      alignment: 0.02,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }
}

/// 加载占位页：预取中的过渡状态，绝不渲染成“另一篇回答”。
class _LoadingAnswerPlaceholder extends StatelessWidget {
  final bool hasError;
  final bool isLoading;
  final VoidCallback onRetry;

  const _LoadingAnswerPlaceholder({
    required this.hasError,
    required this.isLoading,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasError) ...[
            Icon(
              Icons.cloud_off_outlined,
              size: 36,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              '加载失败',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(onPressed: onRetry, child: const Text('点击重试')),
          ] else if (isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// 单个回答页面内容 (纯内容，无 Scaffold)
class _AnswerSinglePage extends StatefulWidget {
  final String answerId;
  final String? questionId;
  final Map<String, dynamic>? initialData;
  final ValueChanged<String>? onQuestionIdLoaded;
  final ValueChanged<Map<String, dynamic>>? onDataLoaded;
  final ValueChanged<bool> onTitleVisibilityChanged;
  final GlobalKey commentsKey;
  final VoidCallback? onContentReady;
  final int pageIndex;
  final ValueListenable<int> settledPageIndexListenable;
  final ValueChanged<double> onReadingProgressChanged;
  final ValueChanged<bool> onReadingSeekableChanged;

  const _AnswerSinglePage({
    super.key,
    required this.answerId,
    this.questionId,
    this.initialData,
    this.onQuestionIdLoaded,
    this.onDataLoaded,
    required this.onTitleVisibilityChanged,
    required this.commentsKey,
    this.onContentReady,
    required this.pageIndex,
    required this.settledPageIndexListenable,
    required this.onReadingProgressChanged,
    required this.onReadingSeekableChanged,
  });

  @override
  State<_AnswerSinglePage> createState() => _AnswerSinglePageState();
}

class _AnswerSinglePageState extends State<_AnswerSinglePage>
    with AutomaticKeepAliveClientMixin {
  final _loadingState = Rx<LoadingState<Map<String, dynamic>>>(const Loading());
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _questionTitleKey = GlobalKey();
  Map<String, dynamic>? _answerData;
  String? _currentQuestionId;

  // 延迟渲染标记
  bool _renderContent = false;
  bool _contentLayoutReady = false;
  bool _showComments = false;
  ScrollMetrics? _lastScrollMetrics;
  List<String> _imageUrls = const [];
  bool _titleVisibilityUpdateScheduled = false;
  bool _titleIsCovered = false;
  int _loadGeneration = 0;
  late final ReadingSession _readingSession;

  @override
  bool get wantKeepAlive => true; // 保持页面状态

  @override
  void initState() {
    super.initState();
    _currentQuestionId = widget.questionId;
    widget.settledPageIndexListenable.addListener(_onSettledPageChanged);
    _readingSession = ReadingSession(
      kind: 'answer',
      id: widget.answerId,
      scrollController: _scrollController,
      bodyEndKey: widget.commentsKey,
    );
    _readingSession.progress.addListener(_notifyReadingProgress);
    _readingSession.seekable.addListener(_notifyReadingSeekable);

    if (widget.initialData != null) {
      _answerData = widget.initialData;
      _imageUrls = HtmlChunker.extractImageUrls(
        (_answerData!['content'] ?? _answerData!['detail'] ?? '').toString(),
      );
      _loadingState.value = Success(widget.initialData!);
      _renderContent = true; // 数据已预加载，立即渲染（无需等待）
      // 写入缓存，以便 Parent 读取
      if (!AnswerHttp.cache.containsKey(widget.answerId)) {
        AnswerHttp.cache[widget.answerId] = widget.initialData!;
      }
      // 触发 questionId 回调（用于获取回答列表以支持滑动）
      _triggerQuestionIdCallback();
      _recordHistory(_answerData!);
    } else {
      // 检查缓存
      if (AnswerHttp.cache.containsKey(widget.answerId)) {
        _answerData = AnswerHttp.cache[widget.answerId];
        _imageUrls = HtmlChunker.extractImageUrls(
          (_answerData!['content'] ?? _answerData!['detail'] ?? '').toString(),
        );
        _loadingState.value = Success(_answerData!);
        _renderContent = true; // 缓存命中，立即渲染
        // 触发 questionId 回调
        _triggerQuestionIdCallback();
        _recordHistory(_answerData!);
      } else {
        _loadData();
      }
    }
  }

  /// 触发 questionId 回调
  void _triggerQuestionIdCallback() {
    if (_currentQuestionId == null &&
        _answerData != null &&
        _answerData!['question'] != null) {
      _currentQuestionId = _answerData!['question']['id']?.toString();
    }
    if (_currentQuestionId != null && widget.onQuestionIdLoaded != null) {
      // 使用 post frame callback 确保在 build 后调用
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onQuestionIdLoaded!(_currentQuestionId!);
        }
      });
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _readingSession.progress.removeListener(_notifyReadingProgress);
    _readingSession.seekable.removeListener(_notifyReadingSeekable);
    _readingSession.dispose();
    _scrollController.dispose();
    widget.settledPageIndexListenable.removeListener(_onSettledPageChanged);
    super.dispose();
  }

  void _onSettledPageChanged() {
    _maybeShowComments();
    if (widget.settledPageIndexListenable.value == widget.pageIndex) {
      widget.onTitleVisibilityChanged(_titleIsCovered);
      widget.onReadingProgressChanged(_readingSession.progress.value);
      widget.onReadingSeekableChanged(_readingSession.seekable.value);
      if (_answerData != null) _recordHistory(_answerData!);
    }
    _scheduleTitleVisibilityUpdate();
  }

  void _notifyReadingProgress() {
    if (widget.settledPageIndexListenable.value == widget.pageIndex) {
      widget.onReadingProgressChanged(_readingSession.progress.value);
    }
  }

  void _notifyReadingSeekable() {
    if (widget.settledPageIndexListenable.value == widget.pageIndex) {
      widget.onReadingSeekableChanged(_readingSession.seekable.value);
    }
  }

  void seekToProgress(double progress) {
    _readingSession.seekToProgress(progress);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      _lastScrollMetrics = notification.metrics;
      _maybeShowComments();
      _scheduleTitleVisibilityUpdate();
    }
    return false;
  }

  void _scheduleTitleVisibilityUpdate() {
    if (_titleVisibilityUpdateScheduled || !mounted) return;
    _titleVisibilityUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleVisibilityUpdateScheduled = false;
      if (mounted) _updateTitleVisibility();
    });
  }

  void _updateTitleVisibility() {
    if (widget.settledPageIndexListenable.value != widget.pageIndex) return;
    final renderObject = _questionTitleKey.currentContext?.findRenderObject();
    bool covered;
    if (renderObject is RenderBox && renderObject.attached) {
      final titleBottom = renderObject
          .localToGlobal(Offset(0, renderObject.size.height))
          .dy;
      final appBarBottom =
          MediaQuery.viewPaddingOf(context).top + tritiumMobileToolbarHeight;
      covered = titleBottom <= appBarBottom;
    } else {
      // Sliver 被回收只会发生在标题已远离可视区时。
      covered = _scrollController.hasClients && _scrollController.offset > 0;
    }
    if (_titleIsCovered == covered) return;
    _titleIsCovered = covered;
    widget.onTitleVisibilityChanged(covered);
  }

  void _handleContentReady() {
    _contentLayoutReady = true;
    _readingSession.contentReady();
    widget.onContentReady?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeShowComments();
        _updateTitleVisibility();
      }
    });
  }

  void _maybeShowComments() {
    if (!mounted ||
        _showComments ||
        !_contentLayoutReady ||
        widget.settledPageIndexListenable.value != widget.pageIndex) {
      return;
    }
    final anchorContext = widget.commentsKey.currentContext;
    final anchorBox = anchorContext?.findRenderObject() as RenderBox?;
    final metrics = _lastScrollMetrics;
    final anchorTop = anchorBox != null && anchorBox.hasSize
        ? anchorBox.localToGlobal(Offset.zero).dy
        : null;
    if (!shouldPreloadComments(
      anchorTop: anchorTop,
      viewportHeight: MediaQuery.sizeOf(context).height,
      extentAfter: metrics?.extentAfter,
    )) {
      return;
    }
    _readingSession.refresh();
    setState(() => _showComments = true);
  }

  Future<void> _loadData() async {
    final generation = ++_loadGeneration;
    _loadingState.value = const Loading();
    final result = await AnswerHttp.getAnswer(widget.answerId);

    if (!mounted || generation != _loadGeneration) return;

    if (result is Success<Map<String, dynamic>>) {
      _answerData = result.response;
      _imageUrls = HtmlChunker.extractImageUrls(
        (_answerData!['content'] ?? _answerData!['detail'] ?? '').toString(),
      );
      _renderContent = true;
      // 最后更新响应式状态，只触发一次页面构建。
      _loadingState.value = result;
      _recordHistory(_answerData!);

      // 尝试补全 QuestionId
      if (_currentQuestionId == null && _answerData!['question'] != null) {
        _currentQuestionId = _answerData!['question']['id']?.toString();
        if (_currentQuestionId != null && widget.onQuestionIdLoaded != null) {
          widget.onQuestionIdLoaded!(_currentQuestionId!);
        }
      }

      // 通知 Parent 刷新 UI
      if (widget.onDataLoaded != null) {
        widget.onDataLoaded!(_answerData!);
      }
      _scheduleTitleVisibilityUpdate();
    } else if (result is Error) {
      _loadingState.value = Error((result as Error).errMsg);
    }
  }

  void _recordHistory(Map<String, dynamic> data) {
    if (widget.settledPageIndexListenable.value != widget.pageIndex) return;
    final question = data['question'];
    final title = question is Map
        ? question['title']?.toString() ?? '回答详情'
        : '回答详情';
    unawaited(
      ReadingHistoryService.record(
        kind: 'answer',
        id: widget.answerId,
        title: title,
        preview: data['excerpt']?.toString() ?? '',
        url: 'https://www.zhihu.com/answer/${widget.answerId}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Obx(() {
      final state = _loadingState.value;

      if (state is Loading) {
        return const LoadingWidget(msg: '加载中...');
      }

      if (state is Error) {
        return custom.ErrorWidget(
          message: (state as Error).errMsg,
          onRetry: _loadData,
        );
      }

      final data = _answerData!;
      final question = data['question'] as Map<String, dynamic>?;
      final author = data['author'] as Map<String, dynamic>?;

      final content = data['content'] ?? data['detail'] ?? '';
      final excerpt = data['excerpt'] ?? '';

      final questionTitle = question?['title']?.toString() ?? '回答详情';
      final authorName = author?['name'] ?? '匿名用户';
      final authorHeadline = author?['headline'] ?? '';
      final authorAvatar = author?['avatar_url'] ?? '';

      // 获取作者 IP 属地
      String? authorIpLocation;
      final answerTags = data['answer_tag'] as List?;
      if (answerTags != null && answerTags.isNotEmpty) {
        for (final tag in answerTags) {
          if (tag is Map && tag['type'] == 'ip_info') {
            authorIpLocation = tag['text']?.toString();
            break;
          }
        }
      }

      return RepaintBoundary(
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: CustomScrollView(
            key: Key('answer-scroll-${widget.answerId}'),
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: InkWell(
                  onTap: () {
                    if (_currentQuestionId != null) {
                      Get.toNamed(
                        Routes.question,
                        arguments: {'questionId': _currentQuestionId},
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text(
                      questionTitle,
                      key: _questionTitleKey,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
              // Author Info
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: colorScheme.primaryContainer,
                        backgroundImage: authorAvatar.isNotEmpty
                            ? CachedNetworkImageProvider(authorAvatar)
                            : null,
                        child: authorAvatar.isEmpty
                            ? Icon(
                                Icons.person,
                                color: colorScheme.onPrimaryContainer,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authorName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (authorHeadline.isNotEmpty ||
                                authorIpLocation != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (authorHeadline.isNotEmpty) authorHeadline,
                                  ?authorIpLocation,
                                ].join(' · '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 回答内容
              if (_renderContent)
                ChunkedHtmlSliver(
                  key: ValueKey(content.hashCode),
                  content: content.isNotEmpty ? content : '<p>$excerpt</p>',
                  fontSize: 16,
                  imageUrls: _imageUrls,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  onReady: _handleContentReady,
                )
              else
                SliverToBoxAdapter(
                  child: Container(
                    height: 500,
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(top: 100),
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              // 评论区（嵌入在回答内容下方）
              if (_renderContent && widget.answerId.isNotEmpty)
                SliverToBoxAdapter(child: SizedBox(key: widget.commentsKey)),
              if (_showComments && widget.answerId.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => InlineCommentWidget(
                      resourceId: widget.answerId,
                      resourceType: 'answers',
                      showHeader: true,
                    ),
                    childCount: 1,
                  ),
                ),
              // 底部间距
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      );
    });
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
