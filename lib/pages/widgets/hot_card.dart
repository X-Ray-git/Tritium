import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../router/app_pages.dart';
import '../../http/content_http.dart';
import '../../utils/count_format.dart';

/// 热榜卡片组件
///
/// 热度展示接口可靠提供的 `metrics_area.text` / `detail_text`，回答数展示
/// `answer_count`；不再用 `follower_count` 冒充浏览量，未知统计值显示 “—”。
class HotCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final int index;

  const HotCard({super.key, required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final target = data['target'] as Map<String, dynamic>?;

    if (target == null) {
      return const SizedBox.shrink();
    }

    // 提取 questionId 用于预加载
    String? questionId = target['id']?.toString();
    if (questionId == null && target['link'] != null) {
      final url = target['link']['url']?.toString();
      if (url != null) {
        final uri = Uri.tryParse(url);
        if (uri != null && uri.pathSegments.isNotEmpty) {
          if (uri.pathSegments.contains('questions')) {
            final idx = uri.pathSegments.indexOf('questions');
            if (idx + 1 < uri.pathSegments.length) {
              questionId = uri.pathSegments[idx + 1];
            }
          } else {
            questionId = uri.pathSegments.last;
          }
        }
      }
    }

    // 预加载问题详情
    if (questionId != null) {
      QuestionHttp.preload(questionId);
    }

    // 适配多种数据结构
    String title = target['title'] ?? '';
    if (title.isEmpty) {
      title = target['title_area']?['text'] ?? '';
    }

    String excerpt = target['excerpt'] ?? '';
    if (excerpt.isEmpty) {
      excerpt = target['excerpt_area']?['text'] ?? '';
    }

    // 热度：优先 metrics_area.text，兼容 detail_text。
    final metricsText =
        (target['metrics_area'] as Map?)?['text']?.toString() ??
        (data['metrics_area'] as Map?)?['text']?.toString() ??
        '';
    final heatText = metricsText.isNotEmpty
        ? metricsText
        : target['detail_text']?.toString() ??
              data['detail_text']?.toString() ??
              '';

    // 回答数：target 或 feed_specific 中可靠的数值。
    var answerCount = parseCount(target['answer_count']);
    if (answerCount == null) {
      final feedSpecific = data['feed_specific'] as Map?;
      answerCount = parseCount(feedSpecific?['answer_count']);
    }

    // “新/热”标签。
    final rawCardLabel = data['card_label'];
    final labelText =
        (target['label_area'] as Map?)?['text']?.toString() ??
        (data['label_area'] as Map?)?['text']?.toString() ??
        (rawCardLabel is Map
            ? rawCardLabel['text']?.toString()
            : rawCardLabel?.toString()) ??
        '';

    // 缩略图：image_area。
    String? imageUrl;
    final imageArea =
        (target['image_area'] as Map?) ?? (data['image_area'] as Map?);
    if (imageArea != null) {
      imageUrl =
          imageArea['url']?.toString() ??
          imageArea['image_url']?.toString() ??
          (imageArea['images'] is List
              ? (imageArea['images'] as List)
                    .firstWhere(
                      (item) => item is Map && item['url'] != null,
                      orElse: () => const <String, dynamic>{},
                    )['url']
                    ?.toString()
              : null);
    }

    // 排名样式
    Color rankColor;
    if (index < 3) {
      rankColor = [
        const Color(0xFFFF4D4F),
        const Color(0xFFFF7A45),
        const Color(0xFFFFA940),
      ][index];
    } else {
      rankColor = colorScheme.onSurfaceVariant;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: questionId == null
            ? null
            : () => Get.toNamed(
                Routes.question,
                arguments: {'questionId': questionId},
              ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 排名
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: index < 3 ? rankColor.withValues(alpha: 0.1) : null,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: index < 3 ? FontWeight.bold : FontWeight.w500,
                    color: rankColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (labelText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _HotLabelChip(text: labelText, colorScheme: colorScheme),
                    ],
                    const SizedBox(height: 8),
                    // 摘要
                    if (excerpt.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          excerpt,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    // 热度与回答数
                    Row(
                      children: [
                        if (heatText.isNotEmpty)
                          Expanded(
                            child: Text(
                              heatText,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (heatText.isNotEmpty) const SizedBox(width: 12),
                        Icon(
                          Icons.question_answer_outlined,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatCount(answerCount),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                const SizedBox(width: 12),
                _HotThumbnail(url: imageUrl),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HotLabelChip extends StatelessWidget {
  final String text;
  final ColorScheme colorScheme;

  const _HotLabelChip({required this.text, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final isNew = text.contains('新');
    final color = isNew ? colorScheme.primary : colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 热榜缩略图：8px 圆角，占位与错误态在同一裁切范围。
class _HotThumbnail extends StatelessWidget {
  final String url;

  const _HotThumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 84,
        height: 84,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          httpHeaders: const {'Referer': 'https://www.zhihu.com/'},
          fadeInDuration: const Duration(milliseconds: 200),
          fadeOutDuration: const Duration(milliseconds: 100),
          placeholder: (context, url) => ColoredBox(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          ),
          errorWidget: (context, url, error) => ColoredBox(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Icon(
              Icons.image_outlined,
              size: 22,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
