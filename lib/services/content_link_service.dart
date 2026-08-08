import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/widgets/feedback_toast.dart';
import '../http/content_http.dart';
import '../router/app_pages.dart';

/// 知乎内容链接类型。
enum ContentLinkKind { answer, question, article, pin, user, video, external }

/// 规范化后的内容链接目标。
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

  /// 解析任意来源的知乎/外部链接。
  ///
  /// 输入可以是完整 URL、协议相对 URL、站内相对路径（带或不带前导斜线）、
  /// `zhihu://` deep link 或 `link.zhihu.com` 跳转链接；不安全 scheme、
  /// 空输入和无法识别的链接返回 null。
  static ContentLinkTarget? parse(String rawUrl) {
    final uri = normalizeLinkUrl(rawUrl);
    if (uri == null) return null;

    if (uri.scheme == 'zhihu') {
      return _parseZhihuScheme(uri);
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    final host = uri.host.toLowerCase();
    final isZhihu = host == 'zhihu.com' || host.endsWith('.zhihu.com');
    if (!isZhihu) {
      return ContentLinkTarget(kind: ContentLinkKind.external, uri: uri);
    }
    return _parseSegments(uri, uri.pathSegments) ??
        ContentLinkTarget(kind: ContentLinkKind.external, uri: uri);
  }

  /// URL 归一化。
  ///
  /// 去除无效空白、补齐协议相对与站内相对路径、解包 `link.zhihu.com` 跳转
  /// （限制最大解包深度并防止循环重定向）、保留真正的外部 HTTP/HTTPS URL，
  /// 拒绝 `javascript:`、`data:` 等不安全 scheme。
  static Uri? normalizeLinkUrl(String rawUrl) {
    return _normalizeLinkUrl(rawUrl, depth: 0, visited: <String>{});
  }

  static Uri? _normalizeLinkUrl(
    String rawUrl, {
    required int depth,
    required Set<String> visited,
  }) {
    var url = rawUrl.trim();
    if (url.isEmpty) return null;
    if (depth > _maxUnwrapDepth) return null;
    if (!visited.add(url)) return null;

    if (url.startsWith('#')) return null;
    // 去除无效空白：内容中夹带的空白分隔符按空格折叠后再判断。
    if (url.contains(RegExp(r'\s'))) {
      url = url.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    if (url.isEmpty) return null;
    // 折叠后仍含空格说明不是可识别的 URL（例如普通文字），直接拒绝。
    if (url.contains(' ')) return null;

    // 协议相对 URL：//www.zhihu.com/...
    if (url.startsWith('//')) url = 'https:$url';

    var uri = Uri.tryParse(url);
    if (uri == null) return null;

    // 没有 scheme：区分“看起来像域名的开头”与站内相对路径。
    if (uri.scheme.isEmpty) {
      if (url.startsWith('/')) {
        return _normalizeLinkUrl(
          'https://www.zhihu.com$url',
          depth: depth + 1,
          visited: visited,
        );
      }
      final firstSegment = uri.pathSegments.firstOrNull ?? '';
      if (firstSegment.contains('.') && !firstSegment.contains(' ')) {
        // zhihu.com/question/1 这类缺少 scheme 的完整主机名写法。
        return _normalizeLinkUrl(
          'https://$url',
          depth: depth + 1,
          visited: visited,
        );
      }
      return _normalizeLinkUrl(
        'https://www.zhihu.com/$url',
        depth: depth + 1,
        visited: visited,
      );
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https' && scheme != 'zhihu') {
      return null;
    }

    // 解包 link.zhihu.com 跳转链接，防止站内目标误进浏览器。
    if (uri.host.toLowerCase() == 'link.zhihu.com') {
      final target = uri.queryParameters['target'];
      if (target == null || target.isEmpty) return null;
      return _normalizeLinkUrl(target, depth: depth + 1, visited: visited);
    }

    return uri;
  }

  static const _maxUnwrapDepth = 4;

  static ContentLinkTarget? _parseZhihuScheme(Uri uri) {
    final host = uri.host.toLowerCase();
    final segments = <String>[
      if (host.isNotEmpty && !host.contains('.')) host,
      ...uri.pathSegments,
    ];
    final target = _parseSegments(uri, segments);
    if (target == null) {
      // 尚未建设原生页的知乎 deep link 转 HTTPS 交给浏览器。
      return ContentLinkTarget(
        kind: ContentLinkKind.external,
        uri: Uri.https('www.zhihu.com', '/${segments.join('/')}'),
      );
    }
    if (target.kind != ContentLinkKind.video) return target;

    return ContentLinkTarget(
      kind: ContentLinkKind.video,
      id: target.id,
      uri: Uri.https('www.zhihu.com', '/zvideo/${target.id}'),
    );
  }

  /// 按知乎 URL 路径片段解析站内目标。
  static ContentLinkTarget? _parseSegments(Uri uri, List<String> segments) {
    String? numericId(String? value) {
      if (value == null || !RegExp(r'^\d+$').hasMatch(value)) return null;
      return value;
    }

    String? after(String marker) {
      final index = segments.indexOf(marker);
      return index >= 0 && index + 1 < segments.length
          ? segments[index + 1]
          : null;
    }

    // appview：/appview/answer/{id}、/appview/p/{id}、/appview/pin/{id}
    final appviewIndex = segments.indexOf('appview');
    if (appviewIndex >= 0 && appviewIndex + 1 < segments.length) {
      final appviewKind = segments[appviewIndex + 1];
      final appviewId = numericId(
        appviewIndex + 2 < segments.length ? segments[appviewIndex + 2] : null,
      );
      if (appviewId != null && appviewId.isNotEmpty) {
        final target = _parseSegments(uri, [appviewKind, appviewId]);
        if (target != null) return target;
      }
    }

    // oia 机构文章：/oia/articles/{id}
    if (segments.contains('oia')) {
      final articleId = numericId(after('articles'));
      if (articleId != null && articleId.isNotEmpty) {
        return ContentLinkTarget(
          kind: ContentLinkKind.article,
          uri: uri,
          id: articleId,
        );
      }
    }

    final questionId = numericId(after('question') ?? after('questions'));
    final answerId = numericId(after('answer') ?? after('answers'));
    if (answerId != null && answerId.isNotEmpty) {
      return ContentLinkTarget(
        kind: ContentLinkKind.answer,
        uri: uri,
        id: answerId,
        questionId: questionId,
      );
    }
    if (questionId != null && questionId.isNotEmpty) {
      return ContentLinkTarget(
        kind: ContentLinkKind.question,
        uri: uri,
        id: questionId,
      );
    }

    // 专栏文章：/article/{id}、/articles/{id}、/p/{id}
    final articleId = numericId(
      after('article') ?? after('articles') ?? after('p'),
    );
    if (articleId != null && articleId.isNotEmpty) {
      return ContentLinkTarget(
        kind: ContentLinkKind.article,
        uri: uri,
        id: articleId,
      );
    }

    final pinId = numericId(after('pin') ?? after('pins'));
    if (pinId != null && pinId.isNotEmpty) {
      return ContentLinkTarget(kind: ContentLinkKind.pin, uri: uri, id: pinId);
    }

    // 用户与机构统一走用户原生页。
    final userId = after('people') ?? after('org');
    if (userId != null && userId.isNotEmpty) {
      return ContentLinkTarget(
        kind: ContentLinkKind.user,
        uri: uri,
        id: userId,
      );
    }

    final videoId = numericId(after('zvideo') ?? after('video'));
    if (videoId != null && videoId.isNotEmpty) {
      return ContentLinkTarget(
        kind: ContentLinkKind.video,
        uri: uri,
        id: videoId,
      );
    }

    return null;
  }
}

/// 应用内链接打开策略。
///
/// 已有原生页的知乎内容（回答、问题、文章、想法、用户）应用内打开；视频、
/// 话题、机构号、专栏等尚无原生页的知乎目的地与真正的外部网站由系统浏览器
/// 打开；无效链接给出统一反馈，不静默失败。
abstract final class ContentLinkService {
  static Future<void> open(String rawUrl) async {
    final target = ContentLinkTarget.parse(rawUrl);
    if (target == null) {
      TritiumFeedback.warning('无法打开', '链接格式无效');
      return;
    }

    switch (target.kind) {
      case ContentLinkKind.answer:
        if (target.id != null) AnswerHttp.preload(target.id!);
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
        try {
          final opened = await launchUrl(
            target.uri,
            mode: LaunchMode.externalApplication,
          );
          if (!opened) TritiumFeedback.warning('无法打开', '未找到可用的浏览器');
        } catch (_) {
          TritiumFeedback.warning('无法打开', '系统未能启动浏览器');
        }
        return;
    }
  }
}
