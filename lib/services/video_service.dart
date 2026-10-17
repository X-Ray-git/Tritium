import 'package:dio/dio.dart';

import '../http/init.dart';
import '../utils/storage.dart';

/// Lens IDs are not zvideo post IDs. Resolve at playback time: CDN URLs expire.
abstract final class VideoService {
  static Uri? mediaUri(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value);
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }

  static Uri? lensUrl(dynamic data) {
    if (data is! Map || data['playlist'] is! Map) return null;
    final playlist = data['playlist'] as Map;
    for (final quality in ['HD', 'SD', 'LD']) {
      final entry = playlist[quality];
      final uri = entry is Map ? mediaUri(entry['play_url']) : null;
      if (uri != null) return uri;
    }
    return null;
  }

  static Uri? playInfoUrl(dynamic data) {
    if (data is! Map || data['video_play'] is! Map) return null;
    final playlist = data['video_play']['playlist'];
    if (playlist is! Map || playlist['mp4'] is! List) return null;
    final entries = (playlist['mp4'] as List).whereType<Map>().toList();
    num bitrate(Map e) => e['bitrate'] is num ? e['bitrate'] as num : 0;
    entries.sort((a, b) => bitrate(b).compareTo(bitrate(a)));
    for (final entry in entries) {
      final urls = entry['url'];
      if (urls is! List) continue;
      for (final url in urls) {
        final uri = mediaUri(url);
        if (uri != null) return uri;
      }
    }
    return null;
  }

  static Future<Uri> resolve(
    String id, {
    ({String id, String type})? context,
    CancelToken? cancelToken,
  }) async {
    if (!RegExp(r'^\d+$').hasMatch(id)) throw const FormatException('无效的视频 ID');
    try {
      final response = await Request().get(
        'https://lens.zhihu.com/api/v4/videos/$id',
        cancelToken: cancelToken,
      );
      final uri = lensUrl(response.data);
      if (uri != null) return uri;
    } catch (_) {
      if (cancelToken?.isCancelled ?? false) rethrow;
    }
    if (cancelToken?.isCancelled ?? false) throw StateError('请求已取消');
    if (context != null &&
        RegExp(r'^\d+$').hasMatch(context.id) &&
        const {'answer', 'article', 'question'}.contains(context.type)) {
      final cookies = Pref.cookies ?? '';
      final xsrf = RegExp(
        r'(?:^|;\s*)_xsrf=([^;]+)',
      ).firstMatch(cookies)?.group(1);
      final response = await Request().post(
        'https://www.zhihu.com/api/v4/video/play_info',
        queryParameters: {'r': id},
        data: {
          'content_id': context.id,
          'content_type_str': context.type,
          'video_id': id,
          'scene_code': 'answer_detail_web',
          'is_only_video': true,
        },
        options: Options(
          headers: {
            'x-app-za': 'OS=webplayer',
            'x-referer': '',
            'x-xsrftoken': ?xsrf,
          },
        ),
        cancelToken: cancelToken,
      );
      final uri = playInfoUrl(response.data);
      if (uri != null) return uri;
    }
    throw StateError('暂时无法获取视频，可能已失效或需要登录');
  }
}
