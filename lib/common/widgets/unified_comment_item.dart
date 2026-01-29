import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'html/custom_html.dart';
import 'conversation_panel.dart';
import '../widgets/child_comment_panel.dart';
import '../../router/app_pages.dart';

/// 统一评论列表项组件
/// 
/// 适用于一般评论列表和楼中楼评论列表
class UnifiedCommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;
  final String resourceId;
  final String resourceType;
  final bool showChildComments; // 是否显示子评论预览
  final bool isChildComment; // 是否是子评论（楼中楼）本身
  final bool showViewConversation; // 是否显示查看对话按钮
  final VoidCallback? onReplyTap;

  const UnifiedCommentItem({
    super.key,
    required this.comment,
    required this.resourceId,
    required this.resourceType,
    this.showChildComments = true,
    this.isChildComment = false,
    this.showViewConversation = true,
    this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Author handling
    final authorMap = comment['author'] as Map<String, dynamic>?;
    final authorMember = authorMap?['member'] as Map<String, dynamic>?;
    final author = authorMember ?? authorMap;
    
    // ReplyToAuthor handling
    final replyMap = comment['reply_to_author'] as Map<String, dynamic>?;
    final replyMember = replyMap?['member'] as Map<String, dynamic>?;
    final replyToAuthor = replyMember ?? replyMap;

    final content = comment['content'] ?? '';
    // 兼容多种字段名：vote_count, voteup_count, like_count, like
    final voteCount = comment['vote_count'] ?? 
                      comment['voteup_count'] ?? 
                      comment['like_count'] ?? 
                      comment['like'] ?? 0;
    
    final createdTime = comment['created_time'] ?? 0;
    final childCommentCount = comment['child_comment_count'] ?? 0;
    final childComments = comment['child_comments'] as List?;
    
    final authorName = author?['name'] ?? '匿名用户';
    final authorAvatar = author?['avatar_url'] ?? '';
    final authorId = author?['id']?.toString();


    return InkWell(
      onTap: () {
        if (onReplyTap != null) {
          onReplyTap!();
        } else {
          // 默认行为：打开子评论面板
          ChildCommentPanel.show(
            context, 
            parentCommentId: isChildComment ? resourceId : comment['id'].toString(), 
            resourceType: 'comment',
            parentComment: isChildComment ? null : comment,
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧头像
            GestureDetector(
              onTap: () {
                if (authorId != null) {
                  Get.toNamed(Routes.user, arguments: {'userId': authorId});
                }
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.surfaceContainerHighest,
                backgroundImage: (authorAvatar.isNotEmpty)
                    ? CachedNetworkImageProvider(authorAvatar)
                    : null,
                child: (authorAvatar.isEmpty)
                    ? Icon(Icons.person, size: 20, color: colorScheme.onSurfaceVariant)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            
            // 右侧内容区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 用户名和回复对象
                  Row(
                    children: [
                      Text(
                        authorName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.9),
                        ),
                      ),
                      if (replyToAuthor != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.play_arrow_rounded, size: 10, color: colorScheme.outline),
                        ),
                        Text(
                          replyToAuthor['name'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  
                  // 时间和 IP
                  Row(
                    children: [
                      Text(
                        _formatTime(createdTime),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.outline,
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          String? ipLocation;
                          final commentTags = comment['comment_tag'] as List?;
                          if (commentTags != null && commentTags.isNotEmpty) {
                            for (final tag in commentTags) {
                              if (tag is Map && tag['type'] == 'ip_info') {
                                ipLocation = tag['text']?.toString();
                                break;
                              }
                            }
                          }
                          if (ipLocation != null) {
                            return Text(
                              ' · $ipLocation',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.outline,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // 评论内容
                  CustomHtml(
                    content: content,
                    fontSize: 15,
                  ),
                  const SizedBox(height: 8),



                  // 底部操作栏: 点赞、回复
                  Row(
                    children: [
                      _ActionButton(
                        icon: Icons.thumb_up_outlined,
                        label: voteCount > 0 ? voteCount.toString() : '赞',
                        onTap: () {
                          // TODO: 点赞逻辑
                        },
                      ),
                      const SizedBox(width: 24),
                      _ActionButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: childCommentCount > 0 ? childCommentCount.toString() : '回复',
                        onTap: () {
                          if (onReplyTap != null) {
                            onReplyTap!();
                          } else {
                            ChildCommentPanel.show(
                              context, 
                              parentCommentId: isChildComment ? resourceId : comment['id'].toString(), 
                              resourceType: 'comment',
                              parentComment: isChildComment ? null : comment,
                            );
                          }
                        },
                      ),

                      // 查看对话 (楼中楼且有回复对象)
                      if (showViewConversation &&
                          isChildComment && 
                          comment['reply_comment_id'] != null && 
                          comment['reply_comment_id'].toString() != '0' &&
                          comment['reply_comment_id'].toString().isNotEmpty) ...[
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () => ConversationPanel.show(context, startComment: comment),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              '查看对话',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],

                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.more_horiz_rounded, size: 18, color: colorScheme.outline),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          // TODO: 更多操作
                        },
                      ),
                    ],
                  ),

                  // 楼中楼预览 (仅在非子评论且 showChildComments 为 true 时显示)
                  if (showChildComments && !isChildComment && childComments != null && childComments.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...childComments.take(3).map((child) {
                            final cAuthor = child['author']['member'] ?? child['author'];
                            final cName = cAuthor['name'] ?? '匿名用户';
                            final cContent = child['content'] ?? '';
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '$cName: ',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.primary.withValues(alpha: 0.8),
                                      ),
                                    ),
                                    TextSpan(
                                      text: _stripHtml(cContent),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                          if (childCommentCount > 3)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: InkWell(
                                onTap: () {
                                  ChildCommentPanel.show(
                                    context, 
                                    parentCommentId: comment['id'].toString(), 
                                    resourceType: 'comment',
                                    parentComment: comment,
                                  );
                                },
                                child: Text(
                                  '查看全部 $childCommentCount 条回复 >',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int timestamp) {
    if (timestamp == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 365) {
      return '${date.year}-${date.month}-${date.day}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}天前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}小时前';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  String _stripHtml(String htmlString) {
    final RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').trim();
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: colorScheme.outline),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
