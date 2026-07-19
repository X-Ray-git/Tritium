import 'init.dart';
import '../common/constants/constants.dart';

/// 问题相关接口
class QuestionHttp {
  QuestionHttp._();

  // 内存缓存
  static final Map<String, Map<String, dynamic>> cache = {};
  static final Map<String, Future<LoadingState<Map<String, dynamic>>>>
  _pending = {};

  /// 预加载问题
  static void preload(String questionId) {
    if (!cache.containsKey(questionId) && !_pending.containsKey(questionId)) {
      getQuestion(questionId);
    }
  }

  /// 获取问题详情
  /// 使用 www.zhihu.com/api/v4 端点（需要 zse96 签名）
  static Future<LoadingState<Map<String, dynamic>>> getQuestion(
    String questionId,
  ) {
    if (cache.containsKey(questionId)) {
      return Future.value(Success(cache[questionId]!));
    }
    return _pending.putIfAbsent(questionId, () => _fetchQuestion(questionId));
  }

  static Future<LoadingState<Map<String, dynamic>>> _fetchQuestion(
    String questionId,
  ) async {
    try {
      const include =
          'read_count,answer_count,comment_count,follower_count,detail,excerpt,author,topics';
      final response = await Request().get(
        '${ApiPaths.webQuestions}/$questionId?include=$include',
      );

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
      return Error('网络错误: $e');
    } finally {
      _pending.remove(questionId);
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
      const include =
          'badge,topics,comment_count,excerpt,voteup_count,created_time,updated_time,media_detail';

      final Map<String, dynamic>? queryParams = nextUrl == null
          ? {'limit': limit, 'offset': 0, 'sort_by': sortBy, 'include': include}
          : null;

      final response = await Request().get(url, queryParameters: queryParams);

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
  static final Map<String, Future<LoadingState<Map<String, dynamic>>>>
  _pending = {};

  /// 预加载回答
  static void preload(String answerId) {
    if (!cache.containsKey(answerId) && !_pending.containsKey(answerId)) {
      getAnswer(answerId);
    }
  }

  /// 获取回答详情
  /// 使用 www.zhihu.com/api/v4 端点（需要 zse96 签名）
  static Future<LoadingState<Map<String, dynamic>>> getAnswer(String answerId) {
    if (cache.containsKey(answerId)) {
      return Future.value(Success(cache[answerId]!));
    }
    return _pending.putIfAbsent(answerId, () => _fetchAnswer(answerId));
  }

  static Future<LoadingState<Map<String, dynamic>>> _fetchAnswer(
    String answerId,
  ) async {
    try {
      const include =
          'comment_count,voteup_count,created_time,updated_time,content,excerpt,author,question,answer_tag';
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
    } finally {
      _pending.remove(answerId);
    }
  }
}

/// 专栏文章相关接口
class ArticleHttp {
  ArticleHttp._();

  static final Map<String, Map<String, dynamic>> cache = {};
  static final Map<String, Future<LoadingState<Map<String, dynamic>>>>
  _pending = {};

  static void preload(String articleId) {
    if (!cache.containsKey(articleId) && !_pending.containsKey(articleId)) {
      getArticle(articleId);
    }
  }

  /// 获取文章详情
  /// 使用 www.zhihu.com/api/v4 端点（需要 zse96 签名）
  static Future<LoadingState<Map<String, dynamic>>> getArticle(
    String articleId,
  ) {
    if (cache.containsKey(articleId)) {
      return Future.value(Success(cache[articleId]!));
    }
    return _pending.putIfAbsent(articleId, () => _fetchArticle(articleId));
  }

  static Future<LoadingState<Map<String, dynamic>>> _fetchArticle(
    String articleId,
  ) async {
    try {
      const include =
          'intro,content,voteup_count,comment_count,author,created_time,updated_time,excerpt';
      final response = await Request().get(
        '${ApiPaths.webArticles}/$articleId?include=$include',
      );

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
      return Error('网络错误: $e');
    } finally {
      _pending.remove(articleId);
    }
  }
}

/// 想法（Pin）相关接口
class PinHttp {
  PinHttp._();

  static final Map<String, Map<String, dynamic>> cache = {};
  static final Map<String, Future<LoadingState<Map<String, dynamic>>>>
  _pending = {};

  static void preload(String pinId) {
    if (!cache.containsKey(pinId) && !_pending.containsKey(pinId)) {
      getPin(pinId);
    }
  }

  /// 获取想法详情
  static Future<LoadingState<Map<String, dynamic>>> getPin(String pinId) {
    if (cache.containsKey(pinId)) {
      return Future.value(Success(cache[pinId]!));
    }
    return _pending.putIfAbsent(pinId, () => _fetchPin(pinId));
  }

  static Future<LoadingState<Map<String, dynamic>>> _fetchPin(
    String pinId,
  ) async {
    try {
      // 想法 URL 类似 https://api.zhihu.com/pins/382937492
      // 通常不需要太复杂的 params
      final response = await Request().get(
        '${Constants.zhihuApiBase}/pins/$pinId',
      );

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
      return Error('网络错误: $e');
    } finally {
      _pending.remove(pinId);
    }
  }
}
