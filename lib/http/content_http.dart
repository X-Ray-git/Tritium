import 'init.dart';
import '../common/constants/constants.dart';

/// 问题相关接口
class QuestionHttp {
  QuestionHttp._();

  // 内存缓存
  static final Map<String, Map<String, dynamic>> cache = {};
  static final Set<String> _pending = {};

  /// 预加载问题
  static void preload(String questionId) {
    if (!cache.containsKey(questionId) && !_pending.contains(questionId)) {
      getQuestion(questionId);
    }
  }

  /// 获取问题详情
  /// 使用 www.zhihu.com/api/v4 端点（需要 zse96 签名）
  static Future<LoadingState<Map<String, dynamic>>> getQuestion(String questionId) async {
    // 检查缓存
    if (cache.containsKey(questionId)) {
      return Success(cache[questionId]!);
    }
    
    _pending.add(questionId);

    try {
      // 简化 include 参数，参考 Hydrogen 的实现
      const include = 'read_count,answer_count,comment_count,follower_count,detail,excerpt,author,relationship.is_following,topics';
      final response = await Request().get(
        '${ApiPaths.webQuestions}/$questionId?include=$include',
      );

      _pending.remove(questionId);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && !data.containsKey('error')) {
          cache[questionId] = data;
          return Success(data);
        }
        return Error(data['message'] ?? '请求失败');
      }
      return Error('请求失败: ${response.statusCode}');
    } catch (e) {
      _pending.remove(questionId);
      return Error('网络错误: $e');
    }
  }

  /// 获取问题下的回答列表
  static Future<LoadingState<Map<String, dynamic>>> getQuestionAnswers({
    required String questionId,
    String? nextUrl,
    int limit = 20,
    String sortBy = 'default',
  }) async {
    try {
      // 使用 www.zhihu.com/api/v4 端点（需要 zse96 签名）
      // CHANGE: /feeds -> /answers for better answer list
      final url = nextUrl ?? '${ApiPaths.webQuestions}/$questionId/answers';
      // 参考 Hydrogen 的 include 参数
      const include = 'badge,topics,comment_count,excerpt,voteup_count,created_time,updated_time,upvoted_followees,voteup_count,media_detail';
      
      final Map<String, dynamic>? queryParams = nextUrl == null ? {
          'limit': limit,
          'offset': 0,
          'sort_by': sortBy,
          'include': include, 
        } : null;

      final response = await Request().get(
        url,
        queryParameters: queryParams,
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

/// 回答相关接口
class AnswerHttp {
  AnswerHttp._();

  // 内存缓存
  static final Map<String, Map<String, dynamic>> cache = {};

  /// 预加载回答
  static void preload(String answerId) {
    if (!cache.containsKey(answerId)) {
      getAnswer(answerId);
    }
  }

  /// 获取回答详情
  /// 使用 www.zhihu.com/api/v4 端点（需要 zse96 签名）
  static Future<LoadingState<Map<String, dynamic>>> getAnswer(String answerId) async {
    // 检查缓存
    if (cache.containsKey(answerId)) {
      // debugPrint('AnswerHttp: Cache hit for $answerId');
      return Success(cache[answerId]!);
    }

    try {
      const include = 'comment_count,voteup_count,created_time,updated_time,content,excerpt,author,question,answer_tag';
      final response = await Request().get(
        '${ApiPaths.webAnswers}/$answerId?include=$include',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && !data.containsKey('error')) {
          // 写入缓存
          cache[answerId] = data;
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

/// 专栏文章相关接口
class ArticleHttp {
  ArticleHttp._();

  static final Map<String, Map<String, dynamic>> cache = {};
  static final Set<String> _pending = {};

  static void preload(String articleId) {
    if (!cache.containsKey(articleId) && !_pending.contains(articleId)) {
      getArticle(articleId);
    }
  }

  /// 获取文章详情
  /// 使用 www.zhihu.com/api/v4 端点（需要 zse96 签名）
  static Future<LoadingState<Map<String, dynamic>>> getArticle(String articleId) async {
    if (cache.containsKey(articleId)) {
      return Success(cache[articleId]!);
    }
    
    _pending.add(articleId);

    try {
      const include = 'intro,content,voteup_count,comment_count,author,created_time,updated_time,excerpt';
      final response = await Request().get(
        '${ApiPaths.webArticles}/$articleId?include=$include',
      );

      _pending.remove(articleId);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && !data.containsKey('error')) {
          cache[articleId] = data;
          return Success(data);
        }
        return Error(data['message'] ?? '请求失败');
      }
      return Error('请求失败: ${response.statusCode}');
    } catch (e) {
      _pending.remove(articleId);
      return Error('网络错误: $e');
    }
  }
}

/// 想法（Pin）相关接口
class PinHttp {
  PinHttp._();

  static final Map<String, Map<String, dynamic>> cache = {};
  static final Set<String> _pending = {};

  static void preload(String pinId) {
    if (!cache.containsKey(pinId) && !_pending.contains(pinId)) {
      getPin(pinId);
    }
  }

  /// 获取想法详情
  static Future<LoadingState<Map<String, dynamic>>> getPin(String pinId) async {
    if (cache.containsKey(pinId)) {
      return Success(cache[pinId]!);
    }
    
    _pending.add(pinId);

    try {
      // 想法 URL 类似 https://api.zhihu.com/pins/382937492
      // 通常不需要太复杂的 params
      final response = await Request().get(
        '${Constants.zhihuApiBase}/pins/$pinId',
      );

      _pending.remove(pinId);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && !data.containsKey('error')) {
          cache[pinId] = data;
          return Success(data);
        }
        return Error(data['message'] ?? '请求失败');
      }
      return Error('请求失败: ${response.statusCode}');
    } catch (e) {
      _pending.remove(pinId);
      return Error('网络错误: $e');
    }
  }
}
