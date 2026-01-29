import 'init.dart';
import '../common/constants/constants.dart';

/// 用户相关接口
class UserHttp {
  UserHttp._();

  /// 获取用户信息
  static Future<LoadingState<Map<String, dynamic>>> getUserInfo(String urlToken) async {
    try {
      final response = await Request().get(
        '${ApiPaths.people}/$urlToken',
        queryParameters: {
          'include': 'locations,employments,gender,educations,business,voteup_count,thanked_count,follower_count,following_count,cover_url,following_topic_count,following_question_count,following_favlists_count,following_columns_count,avatar_hue,answer_count,articles_count,pins_count,question_count,columns_count,commercial_question_count,favorite_count,favorited_count,logs_count,included_answers_count,included_articles_count,included_text,message_thread_token,account_status,is_active,is_bind_phone,is_force_renamed,is_bind_sina,is_privacy_protected,sina_weibo_url,sina_weibo_name,show_sina_weibo,is_blocking,is_blocked,is_following,is_followed,is_org_createpin_white_user,mutual_followees_count,vote_to_count,vote_from_count,thank_to_count,thank_from_count,thanked_count,description,hosted_live_count,participated_live_count,allow_message,industry_category,org_name,org_homepage,badge[?(type=best_answerer)].topics',
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
        queryParameters: nextUrl == null ? {
          'limit': limit,
          'offset': 0,
          'sort_by': 'created',
          'include': 'data[*].is_normal,admin_closed_comment,reward_info,is_collapsed,annotation_action,annotation_detail,collapse_reason,collapsed_by,suggest_edit,comment_count,can_comment,content,voteup_count,reshipment_settings,comment_permission,mark_infos,created_time,updated_time,review_info,question,excerpt,is_labeled,label_info,relationship.is_authorized,voting,is_author,is_thanked,is_nothelp;data[*].author.badge[?(type=best_answerer)].topics',
        } : null,
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
        queryParameters: nextUrl == null ? {
          'limit': limit,
          'offset': 0,
          'sort_by': 'created',
          'include': 'data[*].comment_count,suggest_edit,is_normal,thumbnail_extra_info,thumbnail,can_comment,comment_permission,admin_closed_comment,content,voteup_count,created,updated,upvoted_followees,voting,review_info,is_labeled,label_info;data[*].author.badge[?(type=best_answerer)].topics',
        } : null,
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
