import 'init.dart';
import '../common/constants/constants.dart';

/// Feed 相关接口
class FeedHttp {
  FeedHttp._();

  /// 获取推荐 Feed
  static Future<LoadingState<Map<String, dynamic>>> getRecommend({
    String? nextUrl,
  }) async {
    try {
      final url = nextUrl ?? '${ApiPaths.topstoryRecommend}?limit=${Constants.defaultPageSize}&action=down';
      final response = await Request().get(url);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && !data.containsKey('error')) {
          return Success(data);
        }
        return Error(data['message'] ?? '请求失败');
      }
      return Error('请求失败: ${response.statusCode}');
    } catch (e) {
      return Error('网络错误: $e');
    }
  }

  /// 获取热榜
  /// 注意：热榜使用 v3 API，路径已包含完整 URL
  static Future<LoadingState<Map<String, dynamic>>> getHotList() async {
    try {
      final response = await Request().get(
        '${ApiPaths.topstoryHotList}?limit=50&mobile=true',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && !data.containsKey('error')) {
          return Success(data);
        }
        return Error(data['message'] ?? '请求失败');
      }
      return Error('请求失败: ${response.statusCode}');
    } catch (e) {
      return Error('网络错误: $e');
    }
  }

  /// 获取 Feed Tab 分类
  static Future<LoadingState<Map<String, dynamic>>> getFeedSections() async {
    try {
      final response = await Request().get(ApiPaths.feedSections);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && !data.containsKey('error')) {
          return Success(data);
        }
        return Error(data['message'] ?? '请求失败');
      }
      return Error('请求失败: ${response.statusCode}');
    } catch (e) {
      return Error('网络错误: $e');
    }
  }

  /// 获取分类 Feed
  static Future<LoadingState<Map<String, dynamic>>> getSectionFeed({
    required String sectionId,
    String? subPageId,
    String? nextUrl,
  }) async {
    try {
      String url;
      if (nextUrl != null) {
        url = nextUrl;
      } else {
        url = '${ApiPaths.feedSection}/$sectionId?channelStyle=0';
        if (subPageId != null) {
          url += '&sub_page_id=$subPageId';
        }
      }
      
      final response = await Request().get(url);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && !data.containsKey('error')) {
          return Success(data);
        }
        return Error(data['message'] ?? '请求失败');
      }
      return Error('请求失败: ${response.statusCode}');
    } catch (e) {
      return Error('网络错误: $e');
    }
  }
}
