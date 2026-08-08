import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/recommendation_item.dart';
import '../../http/feed_http.dart';
import '../../http/init.dart';
import '../../models/common/paging_info.dart';
import '../../common/widgets/loading_widget.dart';
import '../../common/widgets/error_widget.dart' as custom;
import '../../common/widgets/empty_widget.dart';
import '../../common/widgets/app_chrome.dart';
import '../widgets/feed_card.dart';
import '../main/main_controller.dart'; // For scroll-to-top callback
import '../../services/preload_service.dart';
import '../../services/recommendation_feedback_service.dart';
import '../../common/widgets/tritium_refresh_indicator.dart';
import '../../common/widgets/feedback_toast.dart';

typedef RecommendPageLoader =
    Future<LoadingState<Map<String, dynamic>>> Function({String? nextUrl});

/// 推荐页控制器
class RecommendController extends GetxController {
  final loadingState = Rx<LoadingState<List<Map<String, dynamic>>>>(
    const Loading(),
  );
  final feedList = <Map<String, dynamic>>[].obs;
  final isRefreshing = false.obs;
  final isLoadingMore = false.obs;
  final loadMoreError = RxnString();
  final noNewContentNotice = 0.obs;

  final RecommendationSessionFilter _sessionFilter;
  final RecommendationFeedbackService _feedbackService;
  final RecommendPageLoader _pageLoader;
  String? _nextUrl;
  int _loadGeneration = 0;

  RecommendController({
    RecommendationSessionFilter? sessionFilter,
    RecommendationFeedbackService? feedbackService,
    RecommendPageLoader? pageLoader,
  }) : _sessionFilter = sessionFilter ?? RecommendationSessionFilter(),
       _feedbackService = feedbackService ?? RecommendationFeedbackService(),
       _pageLoader =
           pageLoader ??
           (({String? nextUrl}) => FeedHttp.getRecommend(nextUrl: nextUrl));

  bool get hasMore => _nextUrl != null;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  @override
  void onClose() {
    _loadGeneration++;
    super.onClose();
  }

  /// 加载数据
  Future<void> loadData({bool forceNetwork = false}) async {
    final generation = ++_loadGeneration;
    _nextUrl = null;
    loadMoreError.value = null;

    // 优先使用预加载缓存
    final cachedPage = forceNetwork
        ? null
        : PreloadService.instance.consumeRecommendCache();
    if (cachedPage != null && cachedPage.items.isNotEmpty) {
      final items = _sessionFilter.accept(cachedPage.items);
      if (items.isNotEmpty) {
        feedList.value = items;
        _nextUrl = cachedPage.isEnd ? null : cachedPage.nextUrl;
        loadingState.value = Success(items);
        return;
      }
    }

    if (feedList.isEmpty) {
      loadingState.value = const Loading();
    } else {
      isRefreshing.value = true;
    }

    final result = await _pageLoader();
    if (generation != _loadGeneration) return;

    if (result is Success<Map<String, dynamic>>) {
      final data = result.response;
      final items = _sessionFilter.accept(_parseItems(data['data'] ?? []));
      final paging = PagingInfo.fromJson(data['paging']);

      if (items.isEmpty && feedList.isNotEmpty) {
        _nextUrl = null;
        loadingState.value = Success(feedList.toList(growable: false));
        _showNoNewContent();
      } else {
        _nextUrl = paging.isEnd ? null : paging.nextUrl;
        feedList.value = items;
        loadingState.value = Success(items);
      }
    } else if (result is Error) {
      if (feedList.isEmpty) {
        loadingState.value = Error((result as Error).errMsg);
      } else {
        TritiumFeedback.error('刷新失败', (result as Error).errMsg);
      }
    }
    isRefreshing.value = false;
  }

  /// 加载更多
  Future<void> loadMore() async {
    final nextUrl = _nextUrl;
    if (isLoadingMore.value || nextUrl == null) return;
    final generation = _loadGeneration;
    isLoadingMore.value = true;
    loadMoreError.value = null;

    final result = await _pageLoader(nextUrl: nextUrl);
    if (generation != _loadGeneration) {
      isLoadingMore.value = false;
      return;
    }

    if (result is Success<Map<String, dynamic>>) {
      final data = result.response;
      final items = _sessionFilter.accept(_parseItems(data['data'] ?? []));
      final paging = PagingInfo.fromJson(data['paging']);
      final candidateNextUrl = paging.isEnd ? null : paging.nextUrl;

      // A repeated cursor or a page with no new identities must not create an
      // automatic request loop.
      _nextUrl =
          items.isEmpty ||
              candidateNextUrl == null ||
              candidateNextUrl == nextUrl
          ? null
          : candidateNextUrl;
      if (items.isNotEmpty) feedList.addAll(items);
    } else if (result is Error) {
      loadMoreError.value = (result as Error).errMsg;
    }

    isLoadingMore.value = false;
  }

  /// 解析 Feed 项
  List<Map<String, dynamic>> _parseItems(dynamic data) {
    return data is List
        ? data.whereType<Map<String, dynamic>>().toList()
        : const [];
  }

  Future<void> reportVisibleItems(Set<String> stableKeys) {
    final targets = feedList
        .map(RecommendationItemDescriptor.fromRaw)
        .whereType<RecommendationItemDescriptor>()
        .where((item) => stableKeys.contains(item.stableKey))
        .map((item) => item.feedbackTarget)
        .whereType<RecommendationFeedbackTarget>();
    return _feedbackService.reportTouched(targets);
  }

  void reportOpenedItem(Map<String, dynamic> item) {
    final target = RecommendationItemDescriptor.fromRaw(item)?.feedbackTarget;
    if (target != null) unawaited(_feedbackService.reportRead(target));
  }

  void _showNoNewContent() {
    noNewContentNotice.value++;
  }
}

/// 推荐页
class RecommendPage extends StatefulWidget {
  const RecommendPage({super.key});

  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  late RecommendController controller;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listKey = GlobalKey();
  final Map<String, GlobalKey> _itemKeys = <String, GlobalKey>{};
  Worker? _tabWorker;
  Worker? _noticeWorker;
  bool _visibleReportScheduled = false;

  @override
  void initState() {
    super.initState();
    controller = Get.put(RecommendController());
    _scrollController.addListener(_onScroll);
    _noticeWorker = ever<int>(controller.noNewContentNotice, (_) {
      if (!mounted) return;
      TritiumFeedback.info('暂无更多新内容', '本次刷新没有新的推荐内容');
    });

    // 注册滚动到顶部回调
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mainController = Get.find<MainController>();
      mainController.registerScrollToTop(0, _scrollToTop);
      _tabWorker = ever<int>(mainController.currentIndex, (index) {
        if (index == 0) _scheduleVisibleReport();
      });
      _scheduleVisibleReport();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tabWorker?.dispose();
    _noticeWorker?.dispose();
    // 清理回调
    final mainController = Get.find<MainController>();
    mainController.unregisterScrollToTop(0, _scrollToTop);
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 480) {
      controller.loadMore();
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String? _stableKey(Map<String, dynamic> item) =>
      RecommendationItemDescriptor.fromRaw(item)?.stableKey;

  void _scheduleVisibleReport() {
    if (_visibleReportScheduled || !mounted) return;
    _visibleReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibleReportScheduled = false;
      if (!mounted ||
          !_scrollController.hasClients ||
          _scrollController.position.isScrollingNotifier.value) {
        return;
      }
      final mainController = Get.find<MainController>();
      if (mainController.currentIndex.value != 0) return;

      final listBox = _listKey.currentContext?.findRenderObject() as RenderBox?;
      if (listBox == null || !listBox.attached || !listBox.hasSize) return;
      final listOrigin = listBox.localToGlobal(Offset.zero);
      final media = MediaQuery.of(context);
      final visibleTop = _maxDouble(
        listOrigin.dy,
        media.padding.top + tritiumMobileToolbarHeight,
      );
      final visibleBottom = _minDouble(
        listOrigin.dy + listBox.size.height,
        media.size.height - media.padding.bottom - 76,
      );
      if (visibleBottom <= visibleTop) return;
      final visibleRect = Rect.fromLTRB(
        listOrigin.dx,
        visibleTop,
        listOrigin.dx + listBox.size.width,
        visibleBottom,
      );

      final visibleKeys = <String>{};
      for (final entry in _itemKeys.entries) {
        final itemBox =
            entry.value.currentContext?.findRenderObject() as RenderBox?;
        if (itemBox == null || !itemBox.attached || !itemBox.hasSize) continue;
        final origin = itemBox.localToGlobal(Offset.zero);
        final itemRect = origin & itemBox.size;
        if (itemRect.overlaps(visibleRect) &&
            itemRect.intersect(visibleRect).height >= 1) {
          visibleKeys.add(entry.key);
        }
      }
      if (visibleKeys.isNotEmpty) {
        unawaited(controller.reportVisibleItems(visibleKeys));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = controller.loadingState.value;

      if (state is Loading) {
        return const LoadingWidget(msg: '加载中...');
      }

      if (state is Error) {
        return custom.ErrorWidget(
          message: (state as Error).errMsg,
          onRetry: controller.loadData,
        );
      }

      if (controller.feedList.isEmpty) {
        return EmptyWidget(
          message: '暂无推荐内容',
          onAction: controller.loadData,
          actionLabel: '刷新',
        );
      }

      return NotificationListener<ScrollEndNotification>(
        onNotification: (notification) {
          _scheduleVisibleReport();
          return false;
        },
        child: TritiumRefreshIndicator(
          onRefresh: () => controller.loadData(forceNetwork: true),
          child: ListView.builder(
            key: _listKey,
            controller: _scrollController,
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top,
              bottom: 88 + MediaQuery.paddingOf(context).bottom,
            ),
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false, // 已经在子组件 FeedCard 中处理
            // Flutter 3.41 仍使用像素值 cacheExtent；与本地新版的
            // ScrollCacheExtent.pixels(500) 行为一致，并保持 CI 兼容。
            // ignore: deprecated_member_use
            cacheExtent: 500,
            itemCount:
                controller.feedList.length + (controller.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == controller.feedList.length) {
                if (controller.loadMoreError.value != null) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: controller.loadMore,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('加载失败，点击重试'),
                      ),
                    ),
                  );
                }
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final item = controller.feedList[index];
              final stableKey = _stableKey(item);
              if (stableKey == null) {
                return FeedCard(
                  data: item,
                  onContentOpen: () => controller.reportOpenedItem(item),
                );
              }
              final itemKey = _itemKeys.putIfAbsent(
                stableKey,
                () => GlobalKey(),
              );
              _scheduleVisibleReport();
              return KeyedSubtree(
                key: itemKey,
                child: FeedCard(
                  data: item,
                  onContentOpen: () => controller.reportOpenedItem(item),
                ),
              );
            },
          ),
        ),
      );
    });
  }
}

double _maxDouble(double a, double b) => a > b ? a : b;

double _minDouble(double a, double b) => a < b ? a : b;
