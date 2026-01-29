import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../router/app_pages.dart';
import '../../http/content_http.dart'; // For AnswerHttp.preload

/// Feed 卡片组件
class FeedCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const FeedCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // 解析数据 - 支持多种数据格式
    Map<String, dynamic>? target = data['target'] as Map<String, dynamic>?;
    final card = data['card'] as Map<String, dynamic>?;
    final commonCard = data['common_card'] as Map<String, dynamic>?;
    
    // brief 可能是 Map 或 String，需要处理
    Map<String, dynamic>? brief;
    final briefRaw = data['brief'];
    if (briefRaw is Map<String, dynamic>) {
      brief = briefRaw;
    } else if (briefRaw is String) {
      try {
        brief = jsonDecode(briefRaw) as Map<String, dynamic>;
      } catch (e) {
        // debugPrint('FeedCard: Failed to decode brief: $e');
      }
    }
    final feedType = data['feed_type'] ?? data['type'];
    
    // 如果没有 target，尝试从 card 中获取
    if (target == null && card != null) {
      target = card['content'] as Map<String, dynamic>?;
    }
    
    // 如果没有 target，尝试从 brief 获取（参考 Hydrogen resolvedata）
    if (target == null && brief != null) {
      // brief 包含实际的内容数据
      // Hydrogen: local v=v.target or v
      final innerTarget = brief['target'] as Map<String, dynamic>?;
      target = innerTarget ?? brief;
      // debugPrint('FeedCard: Using brief as target (innerTarget: ${innerTarget != null})');
      
      // 调试: 检查 author
      final author = target['author'] as Map<String, dynamic>?;
      if (author == null || author['name'] == null) {
         // debugPrint('FeedCard: Author missing in brief target. Keys: ${target.keys.toList()}');
      }
    }
    
    // 如果有 common_card 格式（Android API 返回格式）
    if (target == null && commonCard != null) {
      return _buildCommonCardWidget(context, commonCard, data, colorScheme);
    }
    
    if (target == null) {
      // 调试: 打印数据结构
      // debugPrint('FeedCard: No target found, data keys: ${data.keys.toList()}');
      return const SizedBox.shrink();
    }

    // 获取类型 - 优先使用 target 中的类型
    final targetType = target['type'];
    final type = targetType ?? feedType ?? '';
    
    // 调试日志
    // debugPrint('FeedCard: type=$type, targetType=$targetType, feedType=$feedType');
    
    // 检查 target 数据完整性
    // 如果从 brief 解析出的 target 缺少关键数据，强制回退到 common_card 渲染
    bool isTargetValid = true;
    if (brief != null) { // 只有当 target 来自 brief 时才进行严格检查
      if (type == 'answer') {
        if (target['question'] == null) isTargetValid = false;
      } else {
        if (target['title'] == null) isTargetValid = false;
      }
    }
    
    // 如果 target 无效（且有 common_card），则回退到 common_card 处理
    if (!isTargetValid && commonCard != null) {
      return _buildCommonCardWidget(context, commonCard, data, colorScheme);
    }
    
    // 根据类型渲染不同卡片
    if (type == 'answer' || targetType == 'answer') {
      return _buildAnswerCard(context, target, colorScheme);
    } else if (type == 'article' || targetType == 'article') {
      return _buildArticleCard(context, target, colorScheme);
    } else if (type == 'zvideo' || targetType == 'zvideo') {
      return _buildVideoCard(context, target, colorScheme);
    } else {
      // 通用卡片 - 检查是否有问题数据
      if (target['question'] != null || target['title'] != null) {
        return _buildAnswerCard(context, target, colorScheme);
      }
      return _buildGenericCard(context, target, colorScheme);
    }
  }

  /// 构建 common_card 格式卡片（Android API 返回格式）
  Widget _buildCommonCardWidget(
    BuildContext context,
    Map<String, dynamic> commonCard,
    Map<String, dynamic> originalData,
    ColorScheme colorScheme,
  ) {
    // debugPrint('FeedCard: Building CommonCard'); 

    // 优先从 brief 获取内容数据
    Map<String, dynamic>? brief;
    final briefRaw = originalData['brief'];
    if (briefRaw is Map<String, dynamic>) {
      brief = briefRaw;
    } else if (briefRaw is String) {
      try {
        brief = jsonDecode(briefRaw) as Map<String, dynamic>;
      } catch (e) {
        // debugPrint('FeedCard common_card: Failed to decode brief: $e');
      }
    }
    
    String title = '';
    String authorName = '匿名用户';
    String? authorAvatar; // 新增头像变量
    String excerpt = '';
    String? imageUrl;
    String jumpUrl = '';
    int voteupCount = 0;
    int commentCount = 0;
    String contentType = '';
    String? questionId;
    String? answerId;
    String? articleId;
    
    bool parsedFromBrief = false;
    
    if (brief != null) {
      // 从 brief 获取数据
      final innerTarget = brief['target'] as Map<String, dynamic>?;
      final target = innerTarget ?? brief;
      contentType = target['type']?.toString() ?? '';
      
      // 获取标题
      if (contentType == 'answer') {
        final question = target['question'] as Map<String, dynamic>?;
        title = question?['title']?.toString() ?? '';
        questionId = question?['id']?.toString();
        answerId = target['id']?.toString();
      } else {
        title = target['title']?.toString() ?? '';
        articleId = target['id']?.toString();
      }
      
      // 只有当标题不为空时才认为 brief 解析成功
      if (title.isNotEmpty) {
        parsedFromBrief = true;
        
        // 获取作者
        final author = target['author'] as Map<String, dynamic>?;
        if (author != null && author['name'] != null) {
          authorName = author['name'].toString();
        } else if (target['source'] != null) {
          // 尝试直接获取 source 字段 (common_card brief 通常由 source 字段提供作者信息)
          final source = target['source'];
          if (source is String) {
            authorName = source;
          } else if (source is Map && source['name'] != null) {
             authorName = source['name'].toString();
          }
        }
        
        // 获取摘要
        excerpt = target['excerpt']?.toString() ?? target['excerpt_title']?.toString() ?? '';
        
        // 获取统计数据
        voteupCount = target['voteup_count'] as int? ?? target['vote_count'] as int? ?? 0;
        commentCount = target['comment_count'] as int? ?? 0;
        
        // debugPrint('FeedCard brief success: type=$contentType, title=$title');
      }
    }
    
    // 如果 brief 解析失败，从 common_card 中提取（备用方案）
    if (!parsedFromBrief) {
      // debugPrint('FeedCard: Brief parsing failed or empty, using common_card structure');
      
      // debugPrint('FeedCard: commonCard keys: ${commonCard.keys.toList()}');
      if (commonCard.containsKey('footline')) {
         // debugPrint('FeedCard: footline: ${commonCard['footline']}');
      }
      if (commonCard.containsKey('action')) {
         // debugPrint('FeedCard: action: ${commonCard['action']}');
      }

      final feedContent = commonCard['feed_content'] as Map<String, dynamic>?;
      if (feedContent == null) {
        return const SizedBox.shrink();
      }
      
      // 获取标题区域
      final titleArea = feedContent['title'] as Map<String, dynamic>?;
      title = titleArea?['panel_text']?.toString() ?? title;
      title = _stripHtml(title);
      
      // 获取作者信息 (from source_line)
      final sourceLine = feedContent['source_line'] as Map<String, dynamic>?;
      if (sourceLine != null && sourceLine['elements'] is List) {
        final elements = sourceLine['elements'] as List;
        for (final element in elements) {
          if (element is Map<String, dynamic>) {
            // 尝试获取作者名
            if (element['text'] != null) {
               final textObj = element['text'];
               final text = textObj['panel_text']?.toString();
               if (text != null && text.isNotEmpty && authorName == '匿名用户') {
                 authorName = text;
               }
            }
            // 尝试获取头像
            if (element['avatar'] != null) {
              final imageObj = element['avatar']['image'];
              if (imageObj != null) {
                // 修正：这里是作者头像，单独存储
                authorAvatar = imageObj['image_url']?.toString();
              }
            }
          }
        }
      }
      
      // 获取摘要
      final contentContainer = feedContent['content'] as Map<String, dynamic>?;
      excerpt = contentContainer?['panel_text']?.toString() ?? excerpt;
      excerpt = _stripHtml(excerpt);
      
      // 获取内容图片 (image_area)
      List? imagesList;
      if (feedContent['images'] is List) {
        imagesList = feedContent['images'] as List;
      } else {
        final imageArea = feedContent['image_area'] as Map<String, dynamic>?;
        imagesList = imageArea?['images'] as List?;
      }
      
      if (imagesList != null && imagesList.isNotEmpty) {
        final firstImage = imagesList[0] as Map<String, dynamic>?;
        imageUrl = firstImage?['url']?.toString();
      }
      
      // 获取跳转链接 (from action.intent_url)
      // Structure: action: {intent_url: https://zhihu.com/..., method: GET}
      final action = commonCard['action'] as Map<String, dynamic>?;
      if (action != null) {
        jumpUrl = action['intent_url']?.toString() ?? '';
      }
      
      // 获取底栏统计 (from footline)
      // Structure: footline: {elements: [{text: {panel_text: 377 赞同 · 78 评论}}]}
      final footline = commonCard['footline'] as Map<String, dynamic>?;
      if (footline != null && footline['elements'] is List) {
         final elements = footline['elements'] as List;
         if (elements.isNotEmpty) {
           final firstEl = elements[0] as Map<String, dynamic>?;
           final text = firstEl?['text']?['panel_text']?.toString();
           // text: "377 赞同 · 78 评论"
           if (text != null) {
             final parts = text.split('·');
             if (parts.isNotEmpty) {
               // 赋值给 helper 供显示
               // 这里我们需要临时改变一下显示逻辑，因为 voteupCount 是 int
               // 我们使用 override 字符串
             }
           }
         }
      }
    }
    
    // 辅助函数：优先使用 direct string
    String getVoteupDisplay() {
       if (!parsedFromBrief) {
          // 尝试从 footline 解析
          final footline = commonCard['footline'] as Map<String, dynamic>?;
          final elements = footline?['elements'] as List?;
          if (elements != null && elements.isNotEmpty) {
             final firstEl = elements[0] as Map<String, dynamic>?;
             final text = firstEl?['text']?['panel_text']?.toString();
             // "377 赞同 · 78 评论" -> split -> "377 赞同 " -> split -> "377"
             if (text != null) {
                final parts = text.split('·');
                if (parts.isNotEmpty) {
                   return parts[0].trim().split(' ')[0];
                }
             }
          }
       }
       return _formatCount(voteupCount);
    }
    
    String getCommentDisplay() {
       if (!parsedFromBrief) {
          final footline = commonCard['footline'] as Map<String, dynamic>?;
          final elements = footline?['elements'] as List?;
          if (elements != null && elements.isNotEmpty) {
             final firstEl = elements[0] as Map<String, dynamic>?;
             final text = firstEl?['text']?['panel_text']?.toString();
             // "377 赞同 · 78 评论"
             if (text != null) {
                final parts = text.split('·');
                if (parts.length > 1) {
                   return parts[1].trim().split(' ')[0];
                }
             }
          }
       }
       return _formatCount(commentCount);
    }
    
    final voteupDisplay = getVoteupDisplay();
    final commentDisplay = getCommentDisplay();
    
    // 如果 contentType 为空（brief 解析失败），尝试从 jumpUrl 解析
    if (contentType.isEmpty && jumpUrl.isNotEmpty) {
       final uri = Uri.tryParse(jumpUrl);
       if (uri != null) {
          // 处理 zhihu:// 协议
          if (uri.scheme == 'zhihu') {
            String type = uri.host;
            List<String> pathSegments = uri.pathSegments;
            
            if (type.isEmpty && pathSegments.isNotEmpty) {
              type = pathSegments[0];
              pathSegments = pathSegments.sublist(1);
            }
            
            String? id;
            if (pathSegments.isNotEmpty) id = pathSegments[0];
            
            if (type == 'answer') {
                 if (id != null && id.isNotEmpty) {
                   contentType = 'answer';
                   answerId = id;
                   // 尝试寻找 questionId? 通常 URL 里没有，但 ID 足够获取详情
                 }
            } else if (type == 'question') {
               if (pathSegments.length > 2 && pathSegments[1] == 'answer') {
                  final aId = pathSegments[2];
                  if (id != null) {
                    contentType = 'answer';
                    questionId = id;
                    answerId = aId;
                  }
               } else if (id != null) {
                  contentType = 'question';
                  questionId = id;
               }
            } else if (type == 'article') {
               if (id != null) {
                 contentType = 'article';
                 articleId = id;
               }
            }
          } else if (uri.scheme == 'http' || uri.scheme == 'https') {
             // 尝试从 HTTP URL 解析
             final segments = uri.pathSegments;
             if (segments.contains('answer')) {
               final index = segments.indexOf('answer');
               if (index + 1 < segments.length) {
                 contentType = 'answer';
                 answerId = segments[index+1];
                 // 尝试反向找 questionId
                 if (index - 1 >= 0 && segments[index-1] != 'question') {
                    // unexpected structure?
                 }
                 if (segments.contains('question')) {
                    final qIdx = segments.indexOf('question');
                    if (qIdx + 1 < segments.length) {
                       questionId = segments[qIdx+1];
                    }
                 }
               }
             } else if (segments.contains('question')) {
               final index = segments.indexOf('question');
               if (index + 1 < segments.length) {
                  // check if answer follows
                  // handled above or separately?
                  // If it's just question without answer
                  if (!segments.contains('answer')) {
                    contentType = 'question';
                    questionId = segments[index+1];
                  }
               }
             } else if (segments.contains('p')) {
               final index = segments.indexOf('p');
                if (index + 1 < segments.length) {
                  contentType = 'article';
                  articleId = segments[index+1];
               }
             } else if (segments.contains('pin')) {
                final index = segments.indexOf('pin');
                if (index + 1 < segments.length) {
                   // Let logic below handle Pin or set it here
                   // The logic below handles 'pin' contentType OR 'jumpUrl' check
                   // So we don't strictly need to set contentType='pin' here but it helps.
                   contentType = 'pin';
                   // Logic below extracts ID from URL again if contentType is pin?
                   // No, logic below does: OR jumpUrl.contains('pin')
                   // So Pin is fine.
                }
             }
          }
       }
    }
    
    // 预加载逻辑
    if (contentType == 'answer' && answerId != null) {
      AnswerHttp.preload(answerId);
    } else if (contentType == 'article' && articleId != null) {
      ArticleHttp.preload(articleId);
    } else if (contentType == 'pin' && jumpUrl.isNotEmpty) {
       // Pin ID 提取并预加载
       final uri = Uri.tryParse(jumpUrl);
       if (uri != null && uri.pathSegments.contains('pin')) {
          final idx = uri.pathSegments.indexOf('pin');
          if (idx + 1 < uri.pathSegments.length) {
             PinHttp.preload(uri.pathSegments[idx + 1]);
          }
       }
    }

    // Card Content Builder (Reusable)
    Widget buildCardContent() {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            if (title.isNotEmpty)
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (title.isNotEmpty) const SizedBox(height: 8),
            // 作者 (带头像)
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: (authorAvatar?.isNotEmpty == true)
                      ? CachedNetworkImageProvider(authorAvatar!)
                      : null,
                  child: (authorAvatar == null || authorAvatar.isEmpty)
                      ? Icon(Icons.person, size: 12, color: colorScheme.onPrimaryContainer)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  authorName,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 摘要
            if (excerpt.isNotEmpty)
              Text(
                excerpt,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            // 图片
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 200),
                  fadeOutDuration: const Duration(milliseconds: 100),
                  placeholder: (context, url) => Container(
                    height: 120,
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // 底部统计
            Row(
              children: [
                Icon(Icons.thumb_up_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(voteupDisplay, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                const SizedBox(width: 16),
                Icon(Icons.chat_bubble_outline, size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(commentDisplay, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      );
    }

    // 构建导航回调
    void Function()? onTap;
    if (contentType == 'answer' && answerId != null) {
      onTap = () => Get.toNamed(Routes.answer, arguments: {
        'questionId': questionId,
        'answerId': answerId,
      });
    } else if (contentType == 'article' && articleId != null) {
      onTap = () => Get.toNamed(Routes.article, arguments: {
        'articleId': articleId,
      });
    } else if (contentType == 'question' && questionId != null) {
      onTap = () => Get.toNamed(Routes.question, arguments: {
        'questionId': questionId,
      });
    } else if (contentType == 'pin' && jumpUrl.isNotEmpty) {
      // Pin ID 从 URL 提取
      String? pinId;
      final uri = Uri.tryParse(jumpUrl);
      if (uri != null && uri.pathSegments.contains('pin')) {
        final idx = uri.pathSegments.indexOf('pin');
        if (idx + 1 < uri.pathSegments.length) {
          pinId = uri.pathSegments[idx + 1];
        }
      }
      if (pinId != null) {
        onTap = () => Get.toNamed(Routes.pin, arguments: {'pinId': pinId});
      }
    }
    
    // 如果没有匹配的导航，使用通用 URL 处理
    onTap ??= () {
      if (jumpUrl.isNotEmpty) {
        _handleCommonCardTap(jumpUrl);
      }
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: buildCardContent(),
      ),
    );
  }

  /// 去除 HTML 标签
  String _stripHtml(String htmlString) {
    if (htmlString.isEmpty) return '';
    // 简单去除标签: <...>
    final RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    // 替换 html 实体
    String text = htmlString.replaceAll(exp, '');
    text = text.replaceAll('&nbsp;', ' ')
               .replaceAll('&quot;', '"')
               .replaceAll('&amp;', '&')
               .replaceAll('&lt;', '<')
               .replaceAll('&gt;', '>');
    return text;
  }

  /// 处理 common_card 卡片点击
  void _handleCommonCardTap(String jumpUrl) {
    if (jumpUrl.isEmpty) return;
    
    // 解析跳转链接
    final uri = Uri.tryParse(jumpUrl);
    if (uri == null) return;
    
    // 处理 zhihu:// 协议
    if (uri.scheme == 'zhihu') {
      String type = uri.host;
      List<String> pathSegments = uri.pathSegments;
      
      // 如果 host 为空，尝试从 pathSegments 获取 (处理 zhihu:///answer/123)
      if (type.isEmpty && pathSegments.isNotEmpty) {
        type = pathSegments[0];
        pathSegments = pathSegments.sublist(1);
      }
      
      if (type.isEmpty) return;
      
      String? id;
      if (pathSegments.isNotEmpty) {
        id = pathSegments[0];
      }
      
      if (type == 'answer') {
           if (id != null && id.isNotEmpty) {
             // 预加载回答
             AnswerHttp.preload(id);
             Get.toNamed(Routes.answer, arguments: {'answerId': id});
           }
      } else if (type == 'question') {
         // zhihu://question/123
         // zhihu://question/123/answer/456
         if (pathSegments.length > 2 && pathSegments[1] == 'answer') {
            final answerId = pathSegments[2];
            if (id != null) {
              Get.toNamed(Routes.answer, arguments: {'questionId': id, 'answerId': answerId});
            }
         } else if (id != null && id.isNotEmpty) {
            Get.toNamed(Routes.question, arguments: {'questionId': id});
         }
      } else if (type == 'article') {
         if (id != null && id.isNotEmpty) {
           Get.toNamed(Routes.article, arguments: {'articleId': id});
         }
      }
    } else if (uri.scheme == 'http' || uri.scheme == 'https') {
      // 尝试从 URL 中解析 ID
      final segments = uri.pathSegments;
      if (segments.contains('answer')) {
        final index = segments.indexOf('answer');
        if (index + 1 < segments.length) {
          Get.toNamed(Routes.answer, arguments: {'answerId': segments[index+1]});
        }
      } else if (segments.contains('question')) {
        final index = segments.indexOf('question');
        if (index + 1 < segments.length) {
           Get.toNamed(Routes.question, arguments: {'questionId': segments[index+1]});
        }
      } else if (segments.contains('p')) { // 专栏文章 /p/123
        final index = segments.indexOf('p');
         if (index + 1 < segments.length) {
           Get.toNamed(Routes.article, arguments: {'articleId': segments[index+1]});
        }
      } else if (segments.contains('zvideo')) { // 视频 /zvideo/123
        // TODO: Video Player Page
        final index = segments.indexOf('zvideo');
        if (index + 1 < segments.length) {
          // For now, maybe just launch URL or show toast
           Get.snackbar('提示', '暂不支持视频播放', margin: const EdgeInsets.all(16));
        }
      } else if (segments.contains('pin')) { // 想法 /pin/123
        final index = segments.indexOf('pin');
        if (index + 1 < segments.length) {
           Get.toNamed(Routes.pin, arguments: {'pinId': segments[index+1]});
        }
      } else {
        // Unknown HTTP URL
        // debugPrint('FeedCard: Unhandled HTTP URL: $jumpUrl');
      }
    } else {
       // Support direct zvideo id?
       // debugPrint('FeedCard: Unhandled Scheme: $jumpUrl');
    }
  }

  /// 构建回答卡片
  Widget _buildAnswerCard(
    BuildContext context,
    Map<String, dynamic> target,
    ColorScheme colorScheme,
  ) {
    // 调试: 打印 target 数据
    // debugPrint('FeedCard Answer Debug: keys=${target.keys.toList()}');
    // debugPrint('FeedCard Answer Debug: title=${target['title']}, question=${target['question']}');
    if (target['question'] != null) {
       // debugPrint('FeedCard Answer Debug: question_title=${target['question']['title']}');
    }
    
    final question = target['question'] as Map<String, dynamic>?;
    final author = target['author'] as Map<String, dynamic>?;
    final excerpt = target['excerpt'] ?? '';
    final voteupCount = target['voteup_count'] ?? 0;
    final commentCount = target['comment_count'] ?? 0;

    final questionTitle = question?['title'] ?? '';
    final authorName = author?['name'] ?? '匿名用户';
    final authorAvatar = author?['avatar_url'] ?? '';

    // 提取 ID
    final questionId = question?['id']?.toString();
    final answerId = target['id']?.toString();

    // 生成 Hero Tag (OpenContainer 不再需要 Hero Tag)
    // final heroTag = 'hero_card_${questionId ?? ''}_${answerId ?? ''}_${target['id'] ?? ''}';

    // OpenContainer logic
    // We cannot easily pass 'allAnswerIds' (context) here unless we have it.
    // If available, we should pass it. But FeedCard data usually doesn't have the full list.
    // The previous implementation used Get.toNamed with just the ID (and sometimes context).
    // Here we will pass what we have.
    
    // Preload
    if (answerId != null) {
      AnswerHttp.preload(answerId);
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Get.toNamed(Routes.answer, arguments: {
          'questionId': questionId,
          'answerId': answerId,
        }),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 问题标题
              Text(
                questionTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              // 作者信息
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: authorAvatar.isNotEmpty
                        ? CachedNetworkImageProvider(authorAvatar)
                        : null,
                    child: authorAvatar.isEmpty
                        ? Icon(Icons.person, size: 12, color: colorScheme.onPrimaryContainer)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      authorName,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 回答摘要
              Text(
                excerpt,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // 底部统计信息
              Row(
                children: [
                  Icon(
                    Icons.thumb_up_outlined,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(voteupCount),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(commentCount),
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
      ),
    );
  }

  /// 构建文章卡片
  Widget _buildArticleCard(
    BuildContext context,
    Map<String, dynamic> target,
    ColorScheme colorScheme,
  ) {
    final title = target['title'] ?? '';
    final author = target['author'] as Map<String, dynamic>?;
    final excerpt = target['excerpt'] ?? '';
    final imageUrl = target['image_url'] ?? '';
    final voteupCount = target['voteup_count'] ?? 0;
    final commentCount = target['comment_count'] ?? 0;

    final authorName = author?['name'] ?? '匿名用户';
    
    // 生成 Hero Tag
    // final heroTag = 'hero_article_${target['id'] ?? ''}';

    // 生成 Hero Tag (OpenContainer 不再需要 Hero Tag，但内部可能仍有 Hero? 不，OpenContainer 自带过度)
    // final heroTag = 'hero_article_${target['id'] ?? ''}'; 
    
    if (target['id'] != null) {
      ArticleHttp.preload(target['id'].toString());
    }

    final articleId = target['id']?.toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Get.toNamed(Routes.article, arguments: {
          'articleId': articleId,
        }),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 200),
                  fadeOutDuration: const Duration(milliseconds: 100),
                  placeholder: (context, url) => Container(
                    height: 160,
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 160,
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.image_not_supported, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // 作者
                  Text(
                    authorName,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 摘要
                  if (excerpt.isNotEmpty)
                    Text(
                      excerpt,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 12),
                  // 底部统计
                  Row(
                    children: [
                      Icon(Icons.thumb_up_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(_formatCount(voteupCount), style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                      const SizedBox(width: 16),
                      Icon(Icons.chat_bubble_outline, size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(_formatCount(commentCount), style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建视频卡片
  Widget _buildVideoCard(
    BuildContext context,
    Map<String, dynamic> target,
    ColorScheme colorScheme,
  ) {
    final title = target['title'] ?? '';
    final author = target['author'] as Map<String, dynamic>?;
    final video = target['video'] as Map<String, dynamic>?;
    final playCount = video?['play_count'] ?? target['play_count'] ?? 0;

    final authorName = author?['name'] ?? '匿名用户';
    final thumbnail = video?['thumbnail'] ?? target['thumbnail_url'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () {
          final url = target['url']?.toString() ?? '';
          if (url.isNotEmpty) {
             _handleCommonCardTap(url);
          } else {
             // Fallback
             Get.snackbar('提示', '暂不支持视频播放', margin: const EdgeInsets.all(16));
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: CachedNetworkImage(
                    imageUrl: thumbnail,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 200),
                    fadeOutDuration: const Duration(milliseconds: 100),
                    placeholder: (context, url) => Container(
                      height: 180,
                      color: colorScheme.surfaceContainerHighest,
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 180,
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.video_library_outlined, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                // 播放按钮
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        authorName,
                        style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                      ),
                      const Spacer(),
                      Icon(Icons.play_circle_outline, size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(_formatCount(playCount), style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建通用卡片
  Widget _buildGenericCard(
    BuildContext context,
    Map<String, dynamic> target,
    ColorScheme colorScheme,
  ) {
    final title = target['title'] ?? target['question']?['title'] ?? '';
    final excerpt = target['excerpt'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () {
          final url = target['url']?.toString() ?? '';
          if (url.isNotEmpty) {
            _handleCommonCardTap(url);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (excerpt.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  excerpt,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 格式化数字
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
