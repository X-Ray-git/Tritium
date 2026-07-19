import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../router/app_pages.dart';
import 'child_comment_panel.dart';
import 'html/custom_html.dart';

/// 只读评论项：展示点赞/回复数量，但不伪装成可写操作。
class UnifiedCommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;
  final String resourceId;
  final String resourceType;
  final bool showChildComments;
  final bool isChildComment;
  final bool enableRepliesNavigation;

  const UnifiedCommentItem({
    super.key,
    required this.comment,
    required this.resourceId,
    required this.resourceType,
    this.showChildComments = true,
    this.isChildComment = false,
    this.enableRepliesNavigation = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final authorMap = comment['author'] as Map<String, dynamic>?;
    final authorMember = authorMap?['member'] as Map<String, dynamic>?;
    final author = authorMember ?? authorMap;
    final replyMap = comment['reply_to_author'] as Map<String, dynamic>?;
    final replyMember = replyMap?['member'] as Map<String, dynamic>?;
    final replyToAuthor = replyMember ?? replyMap;

    final content = comment['content']?.toString() ?? '';
    final voteCount = _asInt(
      comment['vote_count'] ??
          comment['voteup_count'] ??
          comment['like_count'] ??
          comment['like'],
    );
    final childCommentCount = _asInt(comment['child_comment_count']);
    final childComments = comment['child_comments'] as List?;
    final createdTime = _asInt(comment['created_time']);
    final authorName = author?['name']?.toString() ?? '匿名用户';
    final authorAvatar = author?['avatar_url']?.toString() ?? '';
    final authorToken =
        author?['url_token']?.toString() ?? author?['id']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: authorToken == null
                ? null
                : () => Get.toNamed(
                    Routes.user,
                    arguments: {'userId': authorToken},
                  ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: colors.surfaceContainerHighest,
              backgroundImage: authorAvatar.isEmpty
                  ? null
                  : CachedNetworkImageProvider(authorAvatar),
              child: authorAvatar.isEmpty
                  ? Icon(Icons.person, size: 20, color: colors.onSurfaceVariant)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      authorName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    if (replyToAuthor != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 12,
                          color: colors.outline,
                        ),
                      ),
                      Text(
                        replyToAuthor['name']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _metadata(createdTime),
                  style: TextStyle(fontSize: 11, color: colors.outline),
                ),
                const SizedBox(height: 6),
                CustomHtml(content: content, fontSize: 15),
                if (voteCount > 0 || childCommentCount > 0) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 18,
                    runSpacing: 6,
                    children: [
                      if (voteCount > 0)
                        _ReadOnlyMetric(
                          icon: Icons.thumb_up_outlined,
                          label: '$voteCount',
                        ),
                      if (childCommentCount > 0)
                        _ReadOnlyMetric(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: '$childCommentCount 条回复',
                          onTap: enableRepliesNavigation
                              ? () => _openReplies(context)
                              : null,
                        ),
                    ],
                  ),
                ],
                if (showChildComments &&
                    !isChildComment &&
                    childComments != null &&
                    childComments.isNotEmpty)
                  _ChildPreview(
                    comments: childComments,
                    totalCount: childCommentCount,
                    onTap: enableRepliesNavigation
                        ? () => _openReplies(context)
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openReplies(BuildContext context) {
    ChildCommentPanel.show(
      context,
      parentCommentId: isChildComment ? resourceId : comment['id'].toString(),
      parentComment: isChildComment ? null : comment,
    );
  }

  String _metadata(int timestamp) {
    final time = _formatTime(timestamp);
    String? location;
    final tags = comment['comment_tag'] as List?;
    for (final tag in tags ?? const []) {
      if (tag is Map && tag['type'] == 'ip_info') {
        location = tag['text']?.toString();
        break;
      }
    }
    return [
      time,
      location,
    ].whereType<String>().where((item) => item.isNotEmpty).join(' · ');
  }

  static int _asInt(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  static String _formatTime(int timestamp) {
    if (timestamp == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) return '${date.year}-${date.month}-${date.day}';
    if (diff.inDays > 0) return '${diff.inDays}天前';
    if (diff.inHours > 0) return '${diff.inHours}小时前';
    if (diff.inMinutes > 0) return '${diff.inMinutes}分钟前';
    return '刚刚';
  }
}

class _ReadOnlyMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ReadOnlyMetric({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }
}

class _ChildPreview extends StatelessWidget {
  final List comments;
  final int totalCount;
  final VoidCallback? onTap;

  const _ChildPreview({
    required this.comments,
    required this.totalCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...comments.take(3).map((raw) {
                  if (raw is! Map) return const SizedBox.shrink();
                  final authorMap = raw['author'];
                  final member = authorMap is Map ? authorMap['member'] : null;
                  final author = member is Map ? member : authorMap;
                  final name = author is Map
                      ? author['name']?.toString()
                      : null;
                  final text = raw['content']?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${name ?? '匿名用户'}：',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.primary,
                            ),
                          ),
                          TextSpan(
                            text: text
                                .replaceAll(RegExp(r'<[^>]*>'), '')
                                .trim(),
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
                if (totalCount > comments.take(3).length)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '查看全部 $totalCount 条回复',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
