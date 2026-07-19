import 'package:flutter/foundation.dart';
import '../http/feed_http.dart';
import '../http/content_http.dart';
import '../http/init.dart';
import '../models/common/paging_info.dart';

class PreloadedRecommendPage {
  final List<Map<String, dynamic>> items;
  final String? nextUrl;
  final bool isEnd;

  const PreloadedRecommendPage({
    required this.items,
    required this.nextUrl,
    required this.isEnd,
  });
}

/// 预加载服务
///
/// 用于在后台预加载内容，提升用户体验
class PreloadService {
  PreloadService._();
  static final PreloadService _instance = PreloadService._();
  static PreloadService get instance => _instance;

  // 预加载状态
  bool _hotListPreloaded = false;
  bool _recommendPreloaded = false;
  bool _isPreloadingHotDetails = false;
  bool _isPreloadingRecommend = false;

  // 缓存的推荐页数据
  PreloadedRecommendPage? _cachedRecommendPage;

  /// 获取缓存的推荐页数据
  PreloadedRecommendPage? get cachedRecommendPage => _cachedRecommendPage;

  /// 推荐数据是否已预加载
  bool get isRecommendPreloaded =>
      _recommendPreloaded && _cachedRecommendPage != null;

  /// 热榜详情是否已预加载
  bool get isHotListPreloaded => _hotListPreloaded;

  /// 预加载热榜详情
  ///
  /// 预加载前 N 条热榜条目的详情内容
  Future<void> preloadHotListDetails(
    List<Map<String, dynamic>> hotList, {
    int count = 5,
  }) async {
    if (_isPreloadingHotDetails || hotList.isEmpty) return;
    _isPreloadingHotDetails = true;

    debugPrint(
      'PreloadService: Starting hot list details preload for $count items',
    );

    try {
      final itemsToPreload = hotList.take(count);

      for (final item in itemsToPreload) {
        final target = item['target'] as Map<String, dynamic>?;
        if (target == null) continue;

        final type = target['type']?.toString();
        final id = target['id']?.toString();

        if (id == null) continue;

        // 根据类型预加载
        if (type == 'answer') {
          AnswerHttp.preload(id);
        } else if (type == 'article') {
          ArticleHttp.preload(id);
        } else if (type == 'question') {
          QuestionHttp.preload(id);
        }

        // 稍微延迟，避免同时发起太多请求
        await Future.delayed(const Duration(milliseconds: 100));
      }

      _hotListPreloaded = true;
      debugPrint('PreloadService: Hot list details preload completed');
    } catch (e) {
      debugPrint('PreloadService: Hot list details preload failed: $e');
    } finally {
      _isPreloadingHotDetails = false;
    }
  }

  /// 预加载推荐页数据
  ///
  /// 在后台预加载推荐页的条目列表
  Future<void> preloadRecommendList() async {
    if (_isPreloadingRecommend || _recommendPreloaded) return;
    _isPreloadingRecommend = true;

    debugPrint('PreloadService: Starting recommend list preload');

    try {
      final result = await FeedHttp.getRecommend();

      if (result is Success<Map<String, dynamic>>) {
        final data = result.response;
        final List<dynamic> items = data['data'] ?? [];
        final parsedItems = items.whereType<Map<String, dynamic>>().toList();
        final paging = PagingInfo.fromJson(data['paging']);
        _cachedRecommendPage = PreloadedRecommendPage(
          items: parsedItems,
          nextUrl: paging.nextUrl,
          isEnd: paging.isEnd,
        );
        _recommendPreloaded = true;

        debugPrint(
          'PreloadService: Recommend list preloaded with ${parsedItems.length} items',
        );

        // 预加载推荐列表前几条的详情
        _preloadRecommendDetails();
      } else {
        debugPrint('PreloadService: Recommend list preload failed');
      }
    } catch (e) {
      debugPrint('PreloadService: Recommend list preload error: $e');
    } finally {
      _isPreloadingRecommend = false;
    }
  }

  /// 预加载推荐列表的详情内容
  Future<void> _preloadRecommendDetails() async {
    final page = _cachedRecommendPage;
    if (page == null || page.items.isEmpty) return;

    final itemsToPreload = page.items.take(3);

    for (final item in itemsToPreload) {
      final target = item['target'] as Map<String, dynamic>?;
      if (target == null) continue;

      final type = target['type']?.toString();
      final id = target['id']?.toString();

      if (id == null) continue;

      if (type == 'answer') {
        AnswerHttp.preload(id);
      } else if (type == 'article') {
        ArticleHttp.preload(id);
      } else if (type == 'pin') {
        PinHttp.preload(id);
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// 启动预加载流程
  ///
  /// 在应用启动时调用，根据默认启动页安排预加载顺序
  /// [defaultTab] 0 = 推荐页, 1 = 热榜页
  Future<void> startPreload({int defaultTab = 1}) async {
    debugPrint('PreloadService: Starting preload with defaultTab=$defaultTab');

    if (defaultTab == 1) {
      // 默认是热榜页，先让热榜自己加载，然后预加载推荐
      // 热榜详情预加载由 HotController 在加载完成后触发
      await Future.delayed(const Duration(seconds: 2));
      preloadRecommendList();
    } else {
      // 默认是推荐页，预加载热榜
      // 暂时不实现热榜列表的预加载，因为热榜数据较少
    }
  }

  /// 清除预加载缓存
  void clearCache() {
    _cachedRecommendPage = null;
    _hotListPreloaded = false;
    _recommendPreloaded = false;
    debugPrint('PreloadService: Cache cleared');
  }

  /// 消费推荐页缓存
  /// 获取并清除缓存的推荐页数据
  PreloadedRecommendPage? consumeRecommendCache() {
    final data = _cachedRecommendPage;
    _cachedRecommendPage = null;
    _recommendPreloaded = false;
    return data;
  }
}
