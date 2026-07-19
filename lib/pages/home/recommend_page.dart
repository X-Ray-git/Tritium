import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:get/get.dart';

import '../../http/feed_http.dart';
import '../../http/init.dart';
import '../../models/common/paging_info.dart';
import '../../common/widgets/loading_widget.dart';
import '../../common/widgets/error_widget.dart' as custom;
import '../../common/widgets/empty_widget.dart';
import '../widgets/feed_card.dart';
import '../main/main_controller.dart'; // For scroll-to-top callback
import '../../services/preload_service.dart';

/// 推荐页控制器
class RecommendController extends GetxController {
  final loadingState = Rx<LoadingState<List<Map<String, dynamic>>>>(
    const Loading(),
  );
  final feedList = <Map<String, dynamic>>[].obs;
  final isRefreshing = false.obs;
  final isLoadingMore = false.obs;
  final loadMoreError = RxnString();

  String? _nextUrl;
  int _loadGeneration = 0;

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
      feedList.value = cachedPage.items;
      _nextUrl = cachedPage.isEnd ? null : cachedPage.nextUrl;
      loadingState.value = Success(cachedPage.items);
      return;
    }

    if (feedList.isEmpty) {
      loadingState.value = const Loading();
    } else {
      isRefreshing.value = true;
    }

    final result = await FeedHttp.getRecommend();
    if (generation != _loadGeneration) return;

    if (result is Success<Map<String, dynamic>>) {
      final data = result.response;
      final items = _parseItems(data['data'] ?? []);
      _nextUrl = PagingInfo.fromJson(data['paging']).nextUrl;

      feedList.value = items;
      loadingState.value = Success(items);
    } else if (result is Error) {
      if (feedList.isEmpty) {
        loadingState.value = Error((result as Error).errMsg);
      } else {
        Get.snackbar('刷新失败', (result as Error).errMsg);
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

    final result = await FeedHttp.getRecommend(nextUrl: nextUrl);
    if (generation != _loadGeneration) {
      isLoadingMore.value = false;
      return;
    }

    if (result is Success<Map<String, dynamic>>) {
      final data = result.response;
      final items = _parseItems(data['data'] ?? []);
      _nextUrl = PagingInfo.fromJson(data['paging']).nextUrl;

      feedList.addAll(items);
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

  @override
  void initState() {
    super.initState();
    controller = Get.put(RecommendController());
    _scrollController.addListener(_onScroll);

    // 注册滚动到顶部回调
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mainController = Get.find<MainController>();
      mainController.scrollToTopCallback = _scrollToTop;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // 清理回调
    final mainController = Get.find<MainController>();
    if (mainController.scrollToTopCallback == _scrollToTop) {
      mainController.scrollToTopCallback = null;
    }
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

      return RefreshIndicator(
        onRefresh: () => controller.loadData(forceNetwork: true),
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.only(
            top: 8,
            bottom: 88 + MediaQuery.paddingOf(context).bottom,
          ),
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false, // 已经在子组件 FeedCard 中处理
          scrollCacheExtent: const ScrollCacheExtent.pixels(500),
          itemCount: controller.feedList.length + (controller.hasMore ? 1 : 0),
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
            return FeedCard(data: item);
          },
        ),
      );
    });
  }
}
