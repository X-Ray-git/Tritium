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
      final url =
          nextUrl ??
          '${ApiPaths.topstoryRecommend}?limit=${Constants.defaultPageSize}&action=down';
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
}
