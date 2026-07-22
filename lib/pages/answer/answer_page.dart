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
import '../../utils/storage.dart';
import '../../common/widgets/inline_comment_widget.dart';
import '../../common/widgets/blur_container.dart';
import '../../common/widgets/app_chrome.dart';
import '../../utils/comment_preload.dart';

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
  String? _questionId;
  String? _initialAnswerId;

  // 回答列表状态
  List<String> _answerIds = [];
  late final PageController _pageController;
  final Map<String, GlobalKey> _commentKeys = {};
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
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments as Map<String, dynamic>?;

    // 优先使用 Constructor 参数，其次使用 Get.arguments
    _questionId = widget.questionId ?? arguments?['questionId'];
    _initialAnswerId = widget.answerId ?? arguments?['answerId'];

    // 初始化列表
    final passedIds =
        widget.answerIds ??
        (arguments?['answerIds'] as List?)
            ?.map((value) => value?.toString())
            .whereType<String>()
            .toList();

    if (passedIds != null) {
      _answerIds = passedIds;
    } else if (_initialAnswerId != null) {
      // 只有单个 ID
      _answerIds = [_initialAnswerId!];
    }

    // 计算初始索引
    if (_initialAnswerId != null) {
      final index = _answerIds.indexOf(_initialAnswerId!);
      _currentIndex = index >= 0 ? index : 0;
    } else if (_answerIds.isNotEmpty) {
      _currentIndex = widget.initialIndex.clamp(0, _answerIds.length - 1);
    }
    _pageController = PageController(initialPage: _currentIndex);
    _questionTitleNotifier = ValueNotifier('回答详情');
    _voteupCountNotifier = ValueNotifier(0);
    _commentCountNotifier = ValueNotifier(0);
    _settledPageIndexNotifier = ValueNotifier(_currentIndex);
    _syncChromeForCurrentAnswer();

    // 如果列表仅包含单个（且可能是从推荐页进来的），尝试获取完整列表
    if (_answerIds.length <= 1 && _questionId != null) {
      _fetchQuestionAnswers();
    }

    // 初始预加载相邻回答
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _preloadNeighbors(_currentIndex);
    });
  }

  @override
  void dispose() {
    _loadGeneration++;
    _pageController.dispose();
    _showTitleNotifier.dispose();
    _questionTitleNotifier.dispose();
    _voteupCountNotifier.dispose();
    _commentCountNotifier.dispose();
    _settledPageIndexNotifier.dispose();
    super.dispose();
  }

  /// 获取问题下的回答列表
  Future<void> _fetchQuestionAnswers() async {
    if (_questionId == null) return;

    final generation = ++_loadGeneration;
    final result = await QuestionHttp.getQuestionAnswers(
      questionId: _questionId!,
    );

    if (!mounted || generation != _loadGeneration) return;

    if (result is Success<Map<String, dynamic>>) {
      final data = result.response['data'];
      if (data is List) {
        final ids = data
            .whereType<Map>()
            .map((e) => e['id']?.toString())
            .whereType<String>()
            .toList();

        if (ids.isNotEmpty) {
          // 确保当前正在查看的 ID 在列表中
          final currentId = _answerIds.isNotEmpty
              ? _answerIds[_currentIndex]
              : _initialAnswerId;

          if (currentId != null && !ids.contains(currentId)) {
            ids.insert(0, currentId);
          }

          // 更新列表和索引
          setState(() {
            _answerIds = ids;
            if (currentId != null) {
              final newIndex = _answerIds.indexOf(currentId);
              _currentIndex = newIndex >= 0 ? newIndex : 0;
            }
            // 预加载
            _preloadNeighbors(_currentIndex);
            // 预加载第一条（如果是热门/首位）
            if (_answerIds.isNotEmpty) {
              AnswerHttp.preload(_answerIds.first);
            }
          });
          _syncChromeForCurrentAnswer();
          _settledPageIndexNotifier.value = _currentIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pageController.hasClients) {
              _pageController.jumpToPage(_currentIndex);
            }
          });
        }
      }
    }
  }

  void _preloadNeighbors(int index) {
    if (_answerIds.isEmpty) return;

    if (index + 1 < _answerIds.length) {
      _preloadAnswer(_answerIds[index + 1]);
    }
    if (index - 1 >= 0) {
      _preloadAnswer(_answerIds[index - 1]);
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
    if (Pref.enableSwipeHaptics) HapticFeedback.selectionClick();
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
    });
    return false;
  }

  void _syncChromeForCurrentAnswer([Map<String, dynamic>? loadedData]) {
    if (_answerIds.isEmpty) return;
    final answerId = _answerIds[_currentIndex];
    final data = loadedData ?? AnswerHttp.cache[answerId];
    _questionTitleNotifier.value =
        data?['question']?['title']?.toString() ?? '回答详情';
    _voteupCountNotifier.value = data?['voteup_count'] ?? 0;
    _commentCountNotifier.value = data?['comment_count'] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_answerIds.isEmpty) {
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
      ),
      body: NotificationListener<ScrollEndNotification>(
        onNotification: _handlePageScrollEnd,
        child: PageView.builder(
          controller: _pageController,
          allowImplicitScrolling: true,
          itemCount: _answerIds.length,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            final answerId = _answerIds[index];
            final commentKey = _commentKeys.putIfAbsent(
              answerId,
              GlobalKey.new,
            );
            return _AnswerSinglePage(
              key: ValueKey(answerId),
              answerId: answerId,
              questionId: _questionId,
              commentsKey: commentKey,
              pageIndex: index,
              settledPageIndexListenable: _settledPageIndexNotifier,
              initialData: AnswerHttp.cache.containsKey(answerId)
                  ? AnswerHttp.cache[answerId]
                  : null,
              onQuestionIdLoaded: (qId) {
                if (_questionId == null && qId.isNotEmpty) {
                  _questionId = qId;
                  _fetchQuestionAnswers();
                }
              },
              onDataLoaded: (data) {
                if (!_hasPendingPageTransition &&
                    _answerIds[_currentIndex] == answerId) {
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
            );
          },
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
                label: _formatCount(count),
              ),
            ),
            const SizedBox(width: 16),
            ValueListenableBuilder<dynamic>(
              valueListenable: _commentCountNotifier,
              builder: (context, count, child) => _ActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: _formatCount(count),
                onTap: () => _scrollToComments(_answerIds[_currentIndex]),
              ),
            ),
          ],
        ),
      ),
    );
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

  String _formatCount(dynamic count) {
    if (count == null) return '0';
    final num = count is int ? count : int.tryParse(count.toString()) ?? 0;
    if (num >= 10000) {
      return '${(num / 10000).toStringAsFixed(1)}万';
    }
    if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}k';
    }
    return num.toString();
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

  @override
  bool get wantKeepAlive => true; // 保持页面状态

  @override
  void initState() {
    super.initState();
    _currentQuestionId = widget.questionId;
    widget.settledPageIndexListenable.addListener(_onSettledPageChanged);

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
    _scrollController.dispose();
    widget.settledPageIndexListenable.removeListener(_onSettledPageChanged);
    super.dispose();
  }

  void _onSettledPageChanged() {
    _maybeShowComments();
    if (widget.settledPageIndexListenable.value == widget.pageIndex) {
      widget.onTitleVisibilityChanged(_titleIsCovered);
    }
    _scheduleTitleVisibilityUpdate();
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
      // Parent 负责 BottomBar，这里不需要 voteup

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
