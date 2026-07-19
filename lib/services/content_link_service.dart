import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../http/content_http.dart';
import '../router/app_pages.dart';

enum ContentLinkKind { answer, question, article, pin, user, video, external }

class ContentLinkTarget {
  final ContentLinkKind kind;
  final Uri uri;
  final String? id;
  final String? questionId;

  const ContentLinkTarget({
    required this.kind,
    required this.uri,
    this.id,
    this.questionId,
  });

  static ContentLinkTarget? parse(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || uri.scheme.isEmpty) return null;

    if (uri.scheme == 'zhihu') return _parseZhihuScheme(uri);
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    final host = uri.host.toLowerCase();
    final isZhihu = host == 'zhihu.com' || host.endsWith('.zhihu.com');
    if (!isZhihu) {
      return ContentLinkTarget(kind: ContentLinkKind.external, uri: uri);
    }

    return _parseSegments(uri, uri.pathSegments) ??
        ContentLinkTarget(kind: ContentLinkKind.external, uri: uri);
  }

  static ContentLinkTarget? _parseZhihuScheme(Uri uri) {
    final segments = <String>[
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments,
    ];
    final target = _parseSegments(uri, segments);
    if (target == null || target.kind != ContentLinkKind.video) return target;

    return ContentLinkTarget(
      kind: ContentLinkKind.video,
      id: target.id,
      uri: Uri.https('www.zhihu.com', '/zvideo/${target.id}'),
    );
  }

  static ContentLinkTarget? _parseSegments(Uri uri, List<String> segments) {
    String? after(String marker) {
      final index = segments.indexOf(marker);
      return index >= 0 && index + 1 < segments.length
          ? segments[index + 1]
          : null;
    }

    final answerId = after('answer') ?? after('answers');
    final questionId = after('question') ?? after('questions');
    if (answerId != null) {
      return ContentLinkTarget(
        kind: ContentLinkKind.answer,
        uri: uri,
        id: answerId,
        questionId: questionId,
      );
    }
    if (questionId != null) {
      return ContentLinkTarget(
        kind: ContentLinkKind.question,
        uri: uri,
        id: questionId,
      );
    }

    final articleId = after('article') ?? after('articles') ?? after('p');
    if (articleId != null) {
      return ContentLinkTarget(
        kind: ContentLinkKind.article,
        uri: uri,
        id: articleId,
      );
    }

    final pinId = after('pin') ?? after('pins');
    if (pinId != null) {
      return ContentLinkTarget(kind: ContentLinkKind.pin, uri: uri, id: pinId);
    }

    final userId = after('people');
    if (userId != null) {
      return ContentLinkTarget(
        kind: ContentLinkKind.user,
        uri: uri,
        id: userId,
      );
    }

    final videoId = after('zvideo');
    if (videoId != null) {
      return ContentLinkTarget(
        kind: ContentLinkKind.video,
        uri: uri,
        id: videoId,
      );
    }

    return null;
  }
}

abstract final class ContentLinkService {
  static Future<void> open(String rawUrl) async {
    final target = ContentLinkTarget.parse(rawUrl);
    if (target == null) {
      Get.snackbar('无法打开', '链接格式无效');
      return;
    }

    switch (target.kind) {
      case ContentLinkKind.answer:
        AnswerHttp.preload(target.id!);
        await Get.toNamed(
          Routes.answer,
          arguments: {
            'answerId': target.id,
            if (target.questionId != null) 'questionId': target.questionId,
          },
        );
        return;
      case ContentLinkKind.question:
        await Get.toNamed(
          Routes.question,
          arguments: {'questionId': target.id},
        );
        return;
      case ContentLinkKind.article:
        await Get.toNamed(Routes.article, arguments: {'articleId': target.id});
        return;
      case ContentLinkKind.pin:
        await Get.toNamed(Routes.pin, arguments: {'pinId': target.id});
        return;
      case ContentLinkKind.user:
        await Get.toNamed(Routes.user, arguments: {'userId': target.id});
        return;
      case ContentLinkKind.video:
      case ContentLinkKind.external:
        final opened = await launchUrl(
          target.uri,
          mode: LaunchMode.externalApplication,
        );
        if (!opened) Get.snackbar('无法打开', '未找到可用的浏览器');
        return;
    }
  }
}
