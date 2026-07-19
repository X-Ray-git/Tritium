import 'init.dart';
import '../common/constants/constants.dart';

/// 用户相关接口
class UserHttp {
  UserHttp._();

  /// 获取用户信息
  static Future<LoadingState<Map<String, dynamic>>> getUserInfo(
    String urlToken,
  ) async {
    try {
      final response = await Request().get(
        '${ApiPaths.people}/$urlToken',
        queryParameters: {
          'include':
              'headline,description,avatar_url,cover_url,gender,follower_count,following_count,answer_count,articles_count,voteup_count',
        },
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

  /// 获取用户回答列表
  static Future<LoadingState<Map<String, dynamic>>> getUserAnswers({
    required String urlToken,
    String? nextUrl,
    int limit = 20,
  }) async {
    try {
      final url = nextUrl ?? '${ApiPaths.people}/$urlToken/answers';
      final response = await Request().get(
        url,
        queryParameters: nextUrl == null
            ? {
                'limit': limit,
                'offset': 0,
                'sort_by': 'created',
                'include':
                    'data[*].comment_count,excerpt,voteup_count,created_time,question,author',
              }
            : null,
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

  /// 获取用户文章列表
  static Future<LoadingState<Map<String, dynamic>>> getUserArticles({
    required String urlToken,
    String? nextUrl,
    int limit = 20,
  }) async {
    try {
      final url = nextUrl ?? '${ApiPaths.people}/$urlToken/articles';
      final response = await Request().get(
        url,
        queryParameters: nextUrl == null
            ? {
                'limit': limit,
                'offset': 0,
                'sort_by': 'created',
                'include':
                    'data[*].comment_count,title,excerpt,voteup_count,created,updated,author',
              }
            : null,
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
