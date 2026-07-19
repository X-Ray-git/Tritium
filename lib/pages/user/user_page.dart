import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../http/user_http.dart';
import '../../http/init.dart';
import '../../models/common/paging_info.dart';
import '../../common/widgets/loading_widget.dart';
import '../../common/widgets/error_widget.dart' as custom;
import '../../router/app_pages.dart';

/// 用户主页
class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage>
    with SingleTickerProviderStateMixin {
  final _loadingState = Rx<LoadingState<Map<String, dynamic>>>(const Loading());
  final _answers = <Map<String, dynamic>>[].obs;
  final _articles = <Map<String, dynamic>>[].obs;
  final _answersLoading = false.obs;
  final _articlesLoading = false.obs;
  final _answersError = RxnString();
  final _articlesError = RxnString();
  final _answersScrollController = ScrollController();
  final _articlesScrollController = ScrollController();

  Map<String, dynamic>? _userData;
  String? _urlToken;
  late TabController _tabController;
  int _loadGeneration = 0;
  String? _answersNextUrl;
  String? _articlesNextUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final arguments = Get.arguments as Map<String, dynamic>?;
    _urlToken = arguments?['urlToken'] ?? arguments?['userId'];
    _answersScrollController.addListener(_loadMoreAnswersIfNeeded);
    _articlesScrollController.addListener(_loadMoreArticlesIfNeeded);
    _loadData();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _answersScrollController
      ..removeListener(_loadMoreAnswersIfNeeded)
      ..dispose();
    _articlesScrollController
      ..removeListener(_loadMoreArticlesIfNeeded)
      ..dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_urlToken == null) {
      _loadingState.value = const Error('用户 ID 无效');
      return;
    }

    final generation = ++_loadGeneration;
    _answersLoading.value = false;
    _articlesLoading.value = false;
    _loadingState.value = const Loading();
    final result = await UserHttp.getUserInfo(_urlToken!);
    if (!mounted || generation != _loadGeneration) return;

    if (result is Success<Map<String, dynamic>>) {
      _userData = result.response;
      _loadingState.value = result;

      // 加载回答和文章
      _loadAnswers(generation, reset: true);
      _loadArticles(generation, reset: true);
    } else if (result is Error) {
      _loadingState.value = Error((result as Error).errMsg);
    }
  }

  Future<void> _loadAnswers(int generation, {bool reset = false}) async {
    if (_answersLoading.value || (!reset && _answersNextUrl == null)) return;
    _answersLoading.value = true;
    _answersError.value = null;
    if (reset) _answersNextUrl = null;

    final result = await UserHttp.getUserAnswers(
      urlToken: _urlToken!,
      nextUrl: reset ? null : _answersNextUrl,
    );
    if (!mounted || generation != _loadGeneration) return;
    if (result is Success<Map<String, dynamic>>) {
      final items =
          (result.response['data'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      if (reset) {
        _answers.value = items;
      } else {
        _answers.addAll(items);
      }
      _answersNextUrl = PagingInfo.fromJson(result.response['paging']).nextUrl;
    } else if (result is Error) {
      _answersError.value = (result as Error).errMsg;
    }
    _answersLoading.value = false;
  }

  Future<void> _loadArticles(int generation, {bool reset = false}) async {
    if (_articlesLoading.value || (!reset && _articlesNextUrl == null)) return;
    _articlesLoading.value = true;
    _articlesError.value = null;
    if (reset) _articlesNextUrl = null;

    final result = await UserHttp.getUserArticles(
      urlToken: _urlToken!,
      nextUrl: reset ? null : _articlesNextUrl,
    );
    if (!mounted || generation != _loadGeneration) return;
    if (result is Success<Map<String, dynamic>>) {
      final items =
          (result.response['data'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      if (reset) {
        _articles.value = items;
      } else {
        _articles.addAll(items);
      }
      _articlesNextUrl = PagingInfo.fromJson(result.response['paging']).nextUrl;
    } else if (result is Error) {
      _articlesError.value = (result as Error).errMsg;
    }
    _articlesLoading.value = false;
  }

  void _loadMoreAnswersIfNeeded() {
    if (_answersScrollController.hasClients &&
        _answersScrollController.position.extentAfter < 400) {
      _loadAnswers(_loadGeneration);
    }
  }

  void _loadMoreArticlesIfNeeded() {
    if (_articlesScrollController.hasClients &&
        _articlesScrollController.position.extentAfter < 400) {
      _loadArticles(_loadGeneration);
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
            appBar: AppBar(title: const Text('用户主页')),
            body: const LoadingWidget(msg: '加载中...'),
          );
        }

        if (state is Error) {
          return Scaffold(
            appBar: AppBar(title: const Text('用户主页')),
            body: custom.ErrorWidget(
              message: (state as Error).errMsg,
              onRetry: _loadData,
            ),
          );
        }

        final data = _userData!;
        final name = data['name'] ?? '未知用户';
        final headline = data['headline'] ?? '';
        final description = data['description'] ?? '';
        final avatarUrl = data['avatar_url'] ?? '';
        final coverUrl = data['cover_url'] ?? '';
        final followerCount = data['follower_count'] ?? 0;
        final followingCount = data['following_count'] ?? 0;
        final answerCount = data['answer_count'] ?? 0;
        final articlesCount = data['articles_count'] ?? 0;
        final voteupCount = data['voteup_count'] ?? 0;
        final gender = data['gender'] is int
            ? data['gender'] as int
            : int.tryParse(data['gender']?.toString() ?? '');

        return NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              // AppBar + 封面
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                title: innerBoxIsScrolled ? Text(name) : null,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 封面图
                      if (coverUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          color: Colors.black45,
                          colorBlendMode: BlendMode.darken,
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary,
                                colorScheme.primaryContainer,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      // 渐变遮罩
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.5),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 用户信息卡片
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -40),
                  child: Column(
                    children: [
                      // 头像
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 4,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: colorScheme.primaryContainer,
                          backgroundImage: avatarUrl.isNotEmpty
                              ? CachedNetworkImageProvider(avatarUrl)
                              : null,
                          child: avatarUrl.isEmpty
                              ? Icon(
                                  Icons.person,
                                  size: 48,
                                  color: colorScheme.onPrimaryContainer,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 用户名
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          if (gender != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              gender == 1 ? Icons.male : Icons.female,
                              size: 20,
                              color: gender == 1 ? Colors.blue : Colors.pink,
                            ),
                          ],
                        ],
                      ),
                      // 签名
                      if (headline.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            headline,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // 统计信息
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StatItem(
                            value: _formatCount(followerCount),
                            label: '关注者',
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            color: colorScheme.outlineVariant,
                          ),
                          _StatItem(
                            value: _formatCount(followingCount),
                            label: '关注了',
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            color: colorScheme.outlineVariant,
                          ),
                          _StatItem(
                            value: _formatCount(voteupCount),
                            label: '获得赞同',
                          ),
                        ],
                      ),
                      // 简介
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              description,
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurface,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              // TabBar
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: '回答 $answerCount'),
                      Tab(text: '文章 $articlesCount'),
                    ],
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                  ),
                  colorScheme.surface,
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              // 回答列表
              _buildAnswersTab(),
              // 文章列表
              _buildArticlesTab(),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildAnswersTab() {
    return Obx(() {
      if (_answers.isEmpty) {
        return _buildEmptyListState(
          loading: _answersLoading.value,
          error: _answersError.value,
          emptyLabel: '暂无回答',
          onRetry: () => _loadAnswers(_loadGeneration, reset: true),
        );
      }
      return ListView.builder(
        controller: _answersScrollController,
        padding: EdgeInsets.zero,
        itemCount: _answers.length + (_answersNextUrl != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _answers.length) {
            return _buildListFooter(
              loading: _answersLoading.value,
              error: _answersError.value,
              onRetry: () => _loadAnswers(_loadGeneration),
            );
          }
          return _AnswerItem(answer: _answers[index]);
        },
      );
    });
  }

  Widget _buildArticlesTab() {
    return Obx(() {
      if (_articles.isEmpty) {
        return _buildEmptyListState(
          loading: _articlesLoading.value,
          error: _articlesError.value,
          emptyLabel: '暂无文章',
          onRetry: () => _loadArticles(_loadGeneration, reset: true),
        );
      }
      return ListView.builder(
        controller: _articlesScrollController,
        padding: EdgeInsets.zero,
        itemCount: _articles.length + (_articlesNextUrl != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _articles.length) {
            return _buildListFooter(
              loading: _articlesLoading.value,
              error: _articlesError.value,
              onRetry: () => _loadArticles(_loadGeneration),
            );
          }
          return _ArticleItem(article: _articles[index]);
        },
      );
    });
  }

  Widget _buildEmptyListState({
    required bool loading,
    required String? error,
    required String emptyLabel,
    required VoidCallback onRetry,
  }) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(error),
        ),
      );
    }
    return Center(child: Text(emptyLabel));
  }

  Widget _buildListFooter({
    required bool loading,
    required String? error,
    required VoidCallback onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: error == null
            ? loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(onPressed: onRetry, child: const Text('继续加载'))
            : TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('加载失败，点击重试'),
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

/// 统计项
class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// TabBar Delegate
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}

/// 回答卡片
class _AnswerItem extends StatelessWidget {
  final Map<String, dynamic> answer;

  const _AnswerItem({required this.answer});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final question = answer['question'] as Map<String, dynamic>?;
    final excerpt = answer['excerpt'] ?? '';
    final voteupCount = answer['voteup_count'] ?? 0;
    final commentCount = answer['comment_count'] ?? 0;

    final questionTitle = question?['title'] ?? '';
    final questionId = question?['id']?.toString();
    final answerId = answer['id']?.toString();

    return InkWell(
      onTap: () {
        if (questionId != null && answerId != null) {
          Get.toNamed(
            Routes.answer,
            arguments: {'questionId': questionId, 'answerId': answerId},
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.thumb_up_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '$voteupCount',
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
                  '$commentCount',
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
    );
  }
}

/// 文章卡片
class _ArticleItem extends StatelessWidget {
  final Map<String, dynamic> article;

  const _ArticleItem({required this.article});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final title = article['title'] ?? '';
    final excerpt = article['excerpt'] ?? '';
    final voteupCount = article['voteup_count'] ?? 0;
    final commentCount = article['comment_count'] ?? 0;
    final articleId = article['id']?.toString();

    return InkWell(
      onTap: () {
        if (articleId != null) {
          Get.toNamed(Routes.article, arguments: {'articleId': articleId});
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
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
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.thumb_up_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '$voteupCount',
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
                  '$commentCount',
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
    );
  }
}
