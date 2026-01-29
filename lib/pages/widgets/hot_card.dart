import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../router/app_pages.dart';
import '../../http/content_http.dart';

/// 热榜卡片组件
class HotCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final int index;

  const HotCard({super.key, required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    final target = data['target'] as Map<String, dynamic>?;
    final detailText = data['detail_text'] ?? '';
    
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

    // 获取统计信息
    dynamic answerCount = target['answer_count'];
    dynamic followerCount = target['follower_count'];
    
    // 尝试从 metrics_area 获取
    if (answerCount == null && target['metrics_area'] != null) {
      final metrics = target['metrics_area'] as Map<String, dynamic>;
      // "text": "23 万热度"
      final text = metrics['text'] ?? '';
      if (text.isNotEmpty) {
        // 将热度作为关注数显示（这就是 detail_text）
        // 如果这里获取不到数字，可以保持为 null
      }
    }
    
    // 尝试从 feed_specific 获取回答数
    if (data['feed_specific'] != null) {
      answerCount ??= data['feed_specific']['answer_count'];
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
        onTap: () {
          if (questionId != null) {
            Get.toNamed(Routes.question, arguments: {'questionId': questionId});
          }
        },
        borderRadius: BorderRadius.circular(12),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // 摘要
                    if (excerpt.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          excerpt,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    // 热度信息
                    Row(
                      children: [
                        if (detailText.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              detailText,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const Spacer(),
                        Icon(
                          Icons.question_answer_outlined,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatCount(answerCount),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.visibility_outlined,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatCount(followerCount),
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
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(dynamic count) {
    if (count == null) return '0';
    final num = count is int ? count : int.tryParse(count.toString()) ?? 0;
    if (num >= 10000) {
      return '${(num / 10000).toStringAsFixed(1)}万';
    }
    if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}k';
    }
    return num.toString();
  }
}
