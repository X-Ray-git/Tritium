import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'init.dart';

class CommentHttp {
  /// 获取评论列表
  /// [id] 资源 ID (回答 ID, 文章 ID 等)
  /// [type] 资源类型 (comments, articles 等 - 但知乎 v5 API 似乎统一用 comment_v5 接口，只需要 ID)
  /// 其实 v5 接口格式是: /comment_v5/answers/{id}/root_comment 或 /comment_v5/articles/{id}/root_comment
  /// Hydrogen 代码中: getUrlByType -> type=="comments" ? .../comment_v5/comment/{id}/child_comment : .../comment_v5/{type}/{id}/root_comment
  /// 所以我们需要区分是 "根评论列表" 还是 "子评论列表"。
  /// 对于回答/文章的评论，type 应该是 answers/articles。
  static Future<LoadingState<Map<String, dynamic>>> getRootComments({
    required String resourceId,
    required String resourceType, // answers, articles, questions, pins
    String orderBy = 'score', // score, ts
    String? nextUrl,
  }) async {
    try {
      Response response;
      if (nextUrl != null) {
        response = await Request().get(nextUrl);
      } else {
        String url;
        if (resourceType == 'comment') {
          // api.zhihu.com/comment_v5/comment/12345/child_comment
          url = '/comment_v5/comment/$resourceId/child_comment';
        } else {
          // api.zhihu.com/comment_v5/answers/12345/root_comment
          url = '/comment_v5/$resourceType/$resourceId/root_comment';
        }
        
        debugPrint('CommentHttp debug: requesting $url with orderBy $orderBy');
        response = await Request().get(
          url,
          queryParameters: {'order_by': orderBy},
        );
      }

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return Success(data);
        }
        return const Error('数据格式错误');
      }
      return Error('请求失败: ${response.statusCode}');
    } catch (e) {
      return Error('网络错误: $e');
    }
  }

  /// 获取子评论（楼中楼）
  static Future<dynamic> getChildComments({
    required String commentId,
    String? nextUrl,
  }) async {
    if (nextUrl != null) {
      return await Request().get(nextUrl);
    }

    // api.zhihu.com/comment_v5/comment/12345/child_comment
    return await Request().get(
      '/comment_v5/comment/$commentId/child_comment',
      queryParameters: {'order_by': 'ts'},
    );
  }

  /// 获取单条评论详情 (用于查看对话)
  static Future<LoadingState<Map<String, dynamic>>> getComment(String commentId) async {
    try {
      // api.zhihu.com/comment_v5/comment/12345
      // 参考 Hydrogen 实现，不带 child_comment
      final response = await Request().get(
        '/comment_v5/comment/$commentId',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return Success(data);
        }
        return const Error('数据格式错误');
      }
      return Error('请求失败: ${response.statusCode}');
    } catch (e) {
      return Error('网络错误: $e');
    }
  }
}
