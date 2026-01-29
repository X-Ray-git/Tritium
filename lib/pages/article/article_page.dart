import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../http/content_http.dart';
import '../../http/init.dart';
import '../../common/widgets/loading_widget.dart';
import '../../common/widgets/error_widget.dart' as custom;
import '../../common/widgets/blur_container.dart';

import '../../common/widgets/html/custom_html.dart';
import '../../common/widgets/inline_comment_widget.dart';

/// 专栏文章页
class ArticlePage extends StatefulWidget {
  final String? articleId;

  const ArticlePage({super.key, this.articleId});

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  final _loadingState = Rx<LoadingState<Map<String, dynamic>>>(const Loading());
  Map<String, dynamic>? _articleData;
  String? _articleId;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments as Map<String, dynamic>?;
    _articleId = widget.articleId ?? arguments?['articleId'];
    
    // 同步检查缓存，确保首帧渲染
    if (_articleId != null && ArticleHttp.cache.containsKey(_articleId)) {
       _articleData = ArticleHttp.cache[_articleId];
       _loadingState.value = Success(_articleData!);
    } else {
       _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_articleId == null) {
      _loadingState.value = const Error('文章 ID 无效');
      return;
    }

    // 如果已经在 initState 中同步加载了缓存并设置了 Success，则无需再次 Loading
    if (_loadingState.value is! Success) {
      _loadingState.value = const Loading();
    }
    
    final result = await ArticleHttp.getArticle(_articleId!);

    if (result is Success<Map<String, dynamic>>) {
      _articleData = result.response;
      _loadingState.value = result;
    } else if (result is Error) {
      _loadingState.value = Error((result as Error).errMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Obx(() {
        final state = _loadingState.value;

        if (state is Loading) {
          return Scaffold(
            appBar: AppBar(title: const Text('专栏文章')),
            body: const LoadingWidget(msg: '加载中...'),
          );
        }

        if (state is Error) {
          return Scaffold(
            appBar: AppBar(title: const Text('专栏文章')),
            body: custom.ErrorWidget(
              message: (state as Error).errMsg,
              onRetry: _loadData,
            ),
          );
        }

        final data = _articleData!;
        
        // 调试: 打印数据 keys
        debugPrint('ArticlePage: keys=${data.keys.toList()}');

        final title = data['title'] ?? '';
        final excerpt = data['excerpt'] ?? '';
        final contentRaw = data['content'] ?? data['detail'];
        final content = (contentRaw != null && contentRaw.toString().isNotEmpty) 
            ? contentRaw 
            : '<p><i>(正文内容为空，显示摘要)</i></p><p>$excerpt</p>';
            
        final author = data['author'] as Map<String, dynamic>?;
        final voteupCount = data['voteup_count'] ?? 0;
        final commentCount = data['comment_count'] ?? 0;
        final imageUrl = data['image_url'] ?? '';
        // createdTime 这里暂不使用
        // final createdTime = data['created'] as int?;

        final authorName = author?['name'] ?? '匿名用户';
        final authorHeadline = author?['headline'] ?? '';
        final authorAvatar = author?['avatar_url'] ?? '';

        // 获取传递的 heroTag
        final arguments = Get.arguments as Map<String, dynamic>?;
        final heroTag = arguments?['heroTag'];

        Widget scaffoldContent = Scaffold(
          body: RefreshIndicator(
            onRefresh: _loadData,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // AppBar
                SliverAppBar(
                  floating: true,
                  snap: true,
                  title: const Text('专栏文章'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {},
                    ),
                  ],
                ),
              // 封面图
              if (imageUrl.isNotEmpty)
                SliverToBoxAdapter(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: colorScheme.surfaceContainerHighest,
                    ),
                    httpHeaders: const {'Referer': 'https://www.zhihu.com/'},
                    errorWidget: (context, url, error) => const SizedBox.shrink(),
                  ),
                ),
              // 标题
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              // 作者信息
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: colorScheme.primaryContainer,
                        backgroundImage: authorAvatar.isNotEmpty
                            ? CachedNetworkImageProvider(authorAvatar)
                            : null,
                        child: authorAvatar.isEmpty
                            ? Icon(Icons.person, color: colorScheme.onPrimaryContainer)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authorName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (authorHeadline.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                authorHeadline,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 32),
                        ),
                        child: const Text('关注'),
                      ),
                    ],
                  ),
                ),
              ),
              // 文章内容
              SliverToBoxAdapter(
                  child: CustomHtml(
                    content: content,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    fontSize: 17,
                  ),
              ),
              // 底部间距
              // 评论区
              SliverToBoxAdapter(
                child: _articleId != null 
                  ? InlineCommentWidget(
                      resourceId: _articleId!,
                      resourceType: 'articles',
                      showHeader: true,
                    )
                  : const SizedBox.shrink(),
              ),

              // 底部间距
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
          // 底部操作栏
          bottomNavigationBar: BlurBottomBar(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 8 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              children: [
                _ActionButton(
                  icon: Icons.thumb_up_outlined,
                  label: _formatCount(voteupCount),
                  onTap: () {},
                ),
                const SizedBox(width: 24),
                _ActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: _formatCount(commentCount),
                  onTap: () {
                    // 滚动到底部查看评论
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );

         // 如果有 heroTag，用 Hero 包裹 Scaffold
        if (heroTag != null && heroTag is String && heroTag.isNotEmpty) {
          return Hero(
            tag: heroTag,
            child: scaffoldContent,
          );
        }
        return scaffoldContent;
      }),
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

/// 操作按钮
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
