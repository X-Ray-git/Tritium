import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../http/feed_http.dart';
import '../../http/init.dart';
import '../../common/widgets/loading_widget.dart';
import '../../common/widgets/error_widget.dart' as custom;
import '../../common/widgets/empty_widget.dart';
import '../widgets/hot_card.dart';
import '../../services/preload_service.dart';

/// 热榜页控制器
class HotController extends GetxController {
  final loadingState = Rx<LoadingState<List<Map<String, dynamic>>>>(const Loading());
  final hotList = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  /// 加载数据
  Future<void> loadData() async {
    loadingState.value = const Loading();
    
    final result = await FeedHttp.getHotList();
    
    if (result is Success<Map<String, dynamic>>) {
      final data = result.response;
      final items = (data['data'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      
      hotList.value = items;
      loadingState.value = Success(items);
      
      // 触发预加载：预加载热榜前 5 条的详情，并在后台预加载推荐页
      _triggerPreload(items);
    } else if (result is Error) {
      loadingState.value = Error((result as Error).errMsg);
    }
  }
  
  /// 触发预加载
  void _triggerPreload(List<Map<String, dynamic>> items) {
    // 延迟一点再预加载，让主要 UI 先渲染
    Future.delayed(const Duration(milliseconds: 500), () {
      // 预加载热榜详情
      PreloadService.instance.preloadHotListDetails(items, count: 5);
      
      // 预加载推荐页数据
      PreloadService.instance.preloadRecommendList();
    });
  }
}

/// 热榜页
class HotPage extends StatelessWidget {
  const HotPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HotController());

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

      return RefreshIndicator(
        onRefresh: controller.loadData,
        child: ListView.builder(
          // 增加底部 Padding 以防止被毛玻璃底栏遮挡
          // kBottomNavigationBarHeight (56) + 额外间距
          padding: EdgeInsets.only(
            top: 8, 
            bottom: 8 + kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom,
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
