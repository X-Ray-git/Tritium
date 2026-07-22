import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../http/feed_http.dart';
import '../../http/init.dart';
import '../../common/widgets/loading_widget.dart';
import '../../common/widgets/error_widget.dart' as custom;
import '../../common/widgets/empty_widget.dart';
import '../widgets/hot_card.dart';
import '../../services/preload_service.dart';
import '../../common/widgets/tritium_refresh_indicator.dart';
import '../main/main_controller.dart';

/// 热榜页控制器
class HotController extends GetxController {
  final loadingState = Rx<LoadingState<List<Map<String, dynamic>>>>(
    const Loading(),
  );
  final hotList = <Map<String, dynamic>>[].obs;
  final isRefreshing = false.obs;
  int _loadGeneration = 0;

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
  Future<void> loadData() async {
    final generation = ++_loadGeneration;
    if (hotList.isEmpty) {
      loadingState.value = const Loading();
    } else {
      isRefreshing.value = true;
    }

    final result = await FeedHttp.getHotList();
    if (generation != _loadGeneration) return;

    if (result is Success<Map<String, dynamic>>) {
      final data = result.response;
      final items =
          (data['data'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
          [];

      hotList.value = items;
      loadingState.value = Success(items);

      // 触发预加载：预加载热榜前 5 条的详情，并在后台预加载推荐页
      _triggerPreload(items, generation);
    } else if (result is Error) {
      if (hotList.isEmpty) {
        loadingState.value = Error((result as Error).errMsg);
      } else {
        Get.snackbar('刷新失败', (result as Error).errMsg);
      }
    }
    isRefreshing.value = false;
  }

  /// 触发预加载
  void _triggerPreload(List<Map<String, dynamic>> items, int generation) {
    // 延迟一点再预加载，让主要 UI 先渲染
    Future.delayed(const Duration(milliseconds: 500), () {
      if (generation != _loadGeneration) return;
      // 预加载热榜详情
      PreloadService.instance.preloadHotListDetails(items, count: 5);

      // 预加载推荐页数据
      PreloadService.instance.preloadRecommendList();
    });
  }
}

/// 热榜页
class HotPage extends StatefulWidget {
  const HotPage({super.key});

  @override
  State<HotPage> createState() => _HotPageState();
}

class _HotPageState extends State<HotPage> {
  late final HotController controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controller = Get.put(HotController());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Get.find<MainController>().registerScrollToTop(1, _scrollToTop);
    });
  }

  @override
  void dispose() {
    Get.find<MainController>().unregisterScrollToTop(1, _scrollToTop);
    _scrollController.dispose();
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

      if (controller.hotList.isEmpty) {
        return EmptyWidget(
          message: '暂无热榜内容',
          onAction: controller.loadData,
          actionLabel: '刷新',
        );
      }

      return TritiumRefreshIndicator(
        onRefresh: controller.loadData,
        child: ListView.builder(
          controller: _scrollController,
          // 增加底部 Padding 以防止被毛玻璃底栏遮挡
          // kBottomNavigationBarHeight (56) + 额外间距
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top,
            bottom: 88 + MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: controller.hotList.length,
          itemBuilder: (context, index) {
            final item = controller.hotList[index];
            return HotCard(data: item, index: index);
          },
        ),
      );
    });
  }
}
