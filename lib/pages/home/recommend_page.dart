import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../http/feed_http.dart';
import '../../http/init.dart';
import '../../common/widgets/loading_widget.dart';
import '../../common/widgets/error_widget.dart' as custom;
import '../../common/widgets/empty_widget.dart';
import '../widgets/feed_card.dart';
import '../main/main_controller.dart'; // For scroll-to-top callback
import '../../services/preload_service.dart';

/// 推荐页控制器
class RecommendController extends GetxController {
  final loadingState = Rx<LoadingState<List<Map<String, dynamic>>>>(const Loading());
  final feedList = <Map<String, dynamic>>[].obs;
  
  String? _nextUrl;
  bool _isLoadingMore = false;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  /// 加载数据
  Future<void> loadData() async {
    _nextUrl = null;
    
    // 优先使用预加载缓存
    final cachedData = PreloadService.instance.consumeRecommendCache();
    if (cachedData != null && cachedData.isNotEmpty) {
      debugPrint('RecommendController: Using preloaded cache with ${cachedData.length} items');
      feedList.value = cachedData;
      loadingState.value = Success(cachedData);
      return;
    }
    
    // 没有缓存，正常加载
    loadingState.value = const Loading();
    
    final result = await FeedHttp.getRecommend();
    
    if (result is Success<Map<String, dynamic>>) {
      final data = result.response;
      final items = _parseItems(data['data'] ?? []);
      _nextUrl = data['paging']?['next'];
      
      feedList.value = items;
      loadingState.value = Success(items);
    } else if (result is Error) {
      loadingState.value = Error((result as Error).errMsg);
    }
  }

  /// 加载更多
  Future<void> loadMore() async {
    if (_isLoadingMore || _nextUrl == null) return;
    _isLoadingMore = true;

    final result = await FeedHttp.getRecommend(nextUrl: _nextUrl);
    
    if (result is Success<Map<String, dynamic>>) {
      final data = result.response;
      final items = _parseItems(data['data'] ?? []);
      _nextUrl = data['paging']?['next'];
      
      feedList.addAll(items);
    }
    
    _isLoadingMore = false;
  }

  /// 解析 Feed 项
  List<Map<String, dynamic>> _parseItems(List<dynamic> data) {
    return data.whereType<Map<String, dynamic>>().toList();
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
    
    // 注册滚动到顶部回调
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mainController = Get.find<MainController>();
      mainController.scrollToTopCallback = _scrollToTop;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // 清理回调
    final mainController = Get.find<MainController>();
    if (mainController.scrollToTopCallback == _scrollToTop) {
      mainController.scrollToTopCallback = null;
    }
    super.dispose();
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
        onRefresh: controller.loadData,
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.only(
            top: 8,
            bottom: 8 + kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom,
          ),
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false, // 已经在子组件 FeedCard 中处理
          cacheExtent: 500, // 增加预渲染范围
          itemCount: controller.feedList.length + 1,
          itemBuilder: (context, index) {
            if (index == controller.feedList.length) {
              // 加载更多
              controller.loadMore();
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
