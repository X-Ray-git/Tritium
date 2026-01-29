import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';

import '../../http/content_http.dart';
import '../../http/init.dart';
import '../../common/widgets/loading_widget.dart';
import '../../common/widgets/error_widget.dart' as custom;
import '../../router/app_pages.dart';
import '../../common/widgets/html/custom_html.dart';
import '../../utils/storage.dart';
import '../../common/widgets/inline_comment_widget.dart';
import '../../common/widgets/blur_container.dart';

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
  // late PageController _pageController; // Removed

  int _currentIndex = 0;
  
  // 滑动方向：true = 从右侧滑入 (Next), false = 从左侧滑入 (Prev)
  bool _slideFromRight = true;
  
  // AppBar 标题可见性（当内容区域的标题滚出视图时显示）
  // bool _showTitleInAppBar = false; // 已废弃，改用 notifier
  final ValueNotifier<bool> _showTitleNotifier = ValueNotifier(false);
  
  // 滚动控制器
  final ScrollController _scrollController = ScrollController();
  static const double _titleScrollThreshold = 60.0; // 标题滚动阈值

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments as Map<String, dynamic>?;
    
    // 优先使用 Constructor 参数，其次使用 Get.arguments
    _questionId = widget.questionId ?? arguments?['questionId'];
    _initialAnswerId = widget.answerId ?? arguments?['answerId'];
    
    // 初始化列表
    final passedIds = widget.answerIds ?? (arguments?['answerIds'] as List?)?.cast<String>();
    
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
    }
    
    // 监听滚动
    // 监听滚动
    _scrollController.addListener(_onScroll);

    // 如果列表仅包含单个（且可能是从推荐页进来的），尝试获取完整列表
    if (_answerIds.length <= 1 && _questionId != null) {
      _fetchQuestionAnswers();
    }

    // 初始预加载相邻回答
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadNeighbors(_currentIndex);
    });
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _showTitleNotifier.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    // 仅更新 ValueNotifier，不触发 setState
    final shouldShow = _scrollController.offset >= _titleScrollThreshold;
    if (_showTitleNotifier.value != shouldShow) {
      _showTitleNotifier.value = shouldShow;
    }
  }

  /// 获取问题下的回答列表
  Future<void> _fetchQuestionAnswers() async {
    if (_questionId == null) return;
    
    debugPrint('AnswerPage: Fetching answers for question $_questionId...');
    final result = await QuestionHttp.getQuestionAnswers(questionId: _questionId!);
    
    if (!mounted) return;

    if (result is Success<Map<String, dynamic>>) {
      final data = result.response['data'];
      if (data is List) {
         final ids = data.map((e) => e['id']?.toString())
             .whereType<String>()
             .toList();
         
         if (ids.isNotEmpty) {
           // 确保当前正在查看的 ID 在列表中
           final currentId = _answerIds.isNotEmpty ? _answerIds[_currentIndex] : _initialAnswerId;
           
           if (currentId != null && !ids.contains(currentId)) {
             ids.insert(0, currentId);
           }
           
           // 更新列表和索引
           setState(() {
             _answerIds = ids;
             if (currentId != null) {
               final newIndex = _answerIds.indexOf(currentId);
               _currentIndex = newIndex >= 0 ? newIndex : 0;
               // 修正位置
               // if (_pageController.hasClients) {
               //   _pageController.jumpToPage(_currentIndex);
               // }
             }
             // 预加载
             _preloadNeighbors(_currentIndex);
             // 预加载第一条（如果是热门/首位）
             if (_answerIds.isNotEmpty) {
               AnswerHttp.preload(_answerIds.first);
             }
           });
           debugPrint('AnswerPage: Updated list with ${ids.length} items. Current index: $_currentIndex');
         }
      }
    }
  }

  // void _onPageChanged(int index) { ... } // Removed

  // void _preloadNeighbors(int index) ... (Keep this)

  void _preloadNeighbors(int index) {
    if (_answerIds.isEmpty) return;
    
    // Preload next
    if (index + 1 < _answerIds.length) {
      AnswerHttp.preload(_answerIds[index + 1]);
    }
    // Preload prev
    if (index - 1 >= 0) {
      AnswerHttp.preload(_answerIds[index - 1]);
    }
    // Preload next+1 (aggressive) ? Maybe just 1 is enough.
  }

  @override
  Widget build(BuildContext context) {
    if (_answerIds.isEmpty) {
      return const Scaffold(body: LoadingWidget(msg: '加载中...'));
    }

    // 获取当前回答数据 (从缓存)
    // 获取当前回答数据 (从缓存)
    final currentId = _answerIds.isNotEmpty ? _answerIds[_currentIndex] : null;
    final currentData = (currentId != null && AnswerHttp.cache.containsKey(currentId)) 
        ? AnswerHttp.cache[currentId] 
        : null;

    final questionTitle = currentData?['question']?['title'] ?? '回答详情';
    final voteupCount = currentData?['voteup_count'] ?? 0;

    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          final colorScheme = Theme.of(context).colorScheme;
          return <Widget>[
            SliverAppBar(
              pinned: true,
              scrolledUnderElevation: 2.0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {},
                ),
              ],
              title: ValueListenableBuilder<bool>(
                valueListenable: _showTitleNotifier,
                builder: (context, show, child) {
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: show ? 1.0 : 0.0,
                    child: Text(
                      questionTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: InkWell(
                onTap: () {
                  if (_questionId != null) {
                    Get.toNamed(Routes.question, arguments: {'questionId': _questionId});
                  }
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Text(
                    questionTitle,
                    style: TextStyle(
                      fontSize: 20, // 大标题
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! < 0) {
              // Swipe Left -> Next
              if (_currentIndex < _answerIds.length - 1) {
                // 触发振动反馈
                if (Pref.enableSwipeHaptics) {
                  HapticFeedback.mediumImpact();
                }
                setState(() {
                  _slideFromRight = true;
                  _currentIndex++;
                  // _showTitleInAppBar = false; // 已移除
                  _updateCurrentData();
                });
                // 切换内容后，重置滚动位置到顶部
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(0);
                }
                _preloadNeighbors(_currentIndex);
              } else {
                Get.snackbar('提示', '已经是最后一条回答了', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 1));
              }
            } else if (details.primaryVelocity! > 0) {
              // Swipe Right -> Prev
              if (_currentIndex > 0) {
                // 触发振动反馈
                if (Pref.enableSwipeHaptics) {
                  HapticFeedback.mediumImpact();
                }
                setState(() {
                  _slideFromRight = false;
                  _currentIndex--;
                  // _showTitleInAppBar = false; // 已移除
                  _updateCurrentData();
                });
                // 切换内容后，重置滚动位置到顶部
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(0);
                }
                _preloadNeighbors(_currentIndex);
              } else {
                Get.snackbar('提示', '已经是第一条回答了', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 1));
              }
            }
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.fastOutSlowIn,
            switchOutCurve: Curves.fastOutSlowIn,
            transitionBuilder: (Widget child, Animation<double> animation) {
              final childKey = child.key as ValueKey?;
              final isEntering = childKey?.value == currentId;
              
              Offset beginOffset;
              if (_slideFromRight) {
                beginOffset = isEntering 
                    ? const Offset(1.0, 0)
                    : const Offset(-1.0, 0);
              } else {
                beginOffset = isEntering 
                    ? const Offset(-1.0, 0)
                    : const Offset(1.0, 0);
              }
              
              return SlideTransition(
                position: Tween<Offset>(
                  begin: beginOffset,
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
            layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
              return Stack(
                children: <Widget>[
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            child: currentId == null 
               ? const LoadingWidget(msg: '加载中...')
               : _AnswerSinglePage(
                  key: ValueKey(currentId),
                  answerId: currentId,
                  questionId: _questionId,
                  initialData: AnswerHttp.cache.containsKey(currentId) 
                      ? AnswerHttp.cache[currentId]
                      : null,
                  onQuestionIdLoaded: (qId) {
                    if (_questionId == null && qId.isNotEmpty) {
                       debugPrint('AnswerPage: Received questionId $qId from child.');
                       _questionId = qId;
                       _fetchQuestionAnswers();
                    }
                  },
                  onDataLoaded: () {
                    // 强制刷新 ScrollController 状态（有时 AnimatedSwitcher 会导致 PrimaryScrollController 丢失连接）
                    setState(() {});
                  },
                  // onTitleVisibilityChanged 已移除，由 parent 直接监听 NestedScrollView controller
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
              _AnimatedActionButton(
                icon: Icons.thumb_up_outlined,
                label: _formatCount(voteupCount),
                onTap: () {},
              ),
              const SizedBox(width: 16),
              _ActionButton(
                icon: Icons.thumb_down_outlined,
                label: '反对',
                onTap: () {},
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.bookmark_border),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () {},
              ),
            ],
          ),
        ),
    );
  }

  // 辅助方法：触发数据更新（其实 setState 已经够了，但为了清晰）
  void _updateCurrentData() {
    // 逻辑在 build 中通过 _currentIndex 获取 currentData
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
  final VoidCallback? onDataLoaded;

  const _AnswerSinglePage({
    super.key, 
    required this.answerId, 
    this.questionId,
    this.initialData,
    this.onQuestionIdLoaded,
    this.onDataLoaded,
  });

  @override
  State<_AnswerSinglePage> createState() => _AnswerSinglePageState();
}

class _AnswerSinglePageState extends State<_AnswerSinglePage> with AutomaticKeepAliveClientMixin {
  final _loadingState = Rx<LoadingState<Map<String, dynamic>>>(const Loading());
  Map<String, dynamic>? _answerData;
  String? _currentQuestionId;
  
  // 延迟渲染标记
  bool _renderContent = false;
  
  @override
  bool get wantKeepAlive => true; // 保持页面状态

  @override
  void initState() {
    super.initState();
    _currentQuestionId = widget.questionId;
    
    // 设置滚动监听
    // _scrollController 移除，交由 NestedScrollView 管理
    
    if (widget.initialData != null) {
      _answerData = widget.initialData;
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
         _loadingState.value = Success(_answerData!);
         _renderContent = true; // 缓存命中，立即渲染
         // 触发 questionId 回调
         _triggerQuestionIdCallback();
      } else {
        _loadData();
        // 仅在需要网络加载时延迟渲染（等待数据到达）
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _answerData != null) {
            setState(() {
              _renderContent = true;
            });
          }
        });
      }
    }
  }
  
  /// 触发 questionId 回调
  void _triggerQuestionIdCallback() {
    if (_currentQuestionId == null && _answerData != null && _answerData!['question'] != null) {
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
    super.dispose();
  }

  Future<void> _loadData() async {
    _loadingState.value = const Loading();
    final result = await AnswerHttp.getAnswer(widget.answerId);

    if (!mounted) return;

    if (result is Success<Map<String, dynamic>>) {
      _answerData = result.response;
      _loadingState.value = result;
      
      // 数据加载完成，允许渲染内容
      setState(() {
        _renderContent = true;
      });
      
      // 尝试补全 QuestionId
      if (_currentQuestionId == null && _answerData!['question'] != null) {
         _currentQuestionId = _answerData!['question']['id']?.toString();
         if (_currentQuestionId != null && widget.onQuestionIdLoaded != null) {
           widget.onQuestionIdLoaded!(_currentQuestionId!);
         }
      }
      
      // 通知 Parent 刷新 UI
      if (widget.onDataLoaded != null) {
        widget.onDataLoaded!();
      }
      
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

      // questionTitle 由 parent widget 使用，此处仅在 child 中加载
  final _ = question?['title'] ?? '';
      final authorName = author?['name'] ?? '匿名用户';
      final authorHeadline = author?['headline'] ?? '';
      final authorAvatar = author?['avatar_url'] ?? '';
      
      // 获取作者 IP 属地
      String? authorIpLocation;
      final answerTags = data['answer_tag'] as List?;
      debugPrint('AnswerPage: answer_tag=$answerTags'); // 调试 IP 属地
      if (answerTags != null && answerTags.isNotEmpty) {
        for (final tag in answerTags) {
          if (tag is Map && tag['type'] == 'ip_info') {
            authorIpLocation = tag['text']?.toString();
            break;
          }
        }
      }

      return RepaintBoundary(
        child: CustomScrollView(
            // controller: _scrollController, // 移除显式 Controller，使用 PrimaryScrollController
            slivers: [
              // 标题已移到父组件 NestedScrollView Header
              // Author Info
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
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
                            ? Icon(Icons.person, color: colorScheme.onPrimaryContainer)
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
                            if (authorHeadline.isNotEmpty || authorIpLocation != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (authorHeadline.isNotEmpty) authorHeadline,
                                  if (authorIpLocation != null) authorIpLocation,
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
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 32),
                        ),
                        child: const Text('关注'),
                      ),
                    ],
                  ),
                ),
              ),
              // 回答内容
              SliverToBoxAdapter(
                    child: _renderContent 
                      ? RepaintBoundary(
                          child: CustomHtml(
                            content: content.isNotEmpty ? content : '<p>$excerpt</p>',
                            fontSize: 16,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          ),
                        )
                      : Container(
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
                SliverToBoxAdapter(
                  child: InlineCommentWidget(
                    resourceId: widget.answerId,
                    resourceType: 'answers',
                    showHeader: true,
                  ),
                ),
              // 底部间距
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
      );
    });
  }

}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AnimatedActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            // 使用 AnimatedSwitcher 平滑过渡数字变化
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Text(
                label,
                key: ValueKey<String>(label), // Key 变化触发动画
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
