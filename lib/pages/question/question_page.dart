import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../http/content_http.dart';
import '../../http/init.dart';
import '../../models/common/paging_info.dart';
import '../../common/widgets/loading_widget.dart';
import '../../common/widgets/error_widget.dart' as custom;
import '../../common/widgets/feedback_toast.dart';
import '../../router/app_pages.dart';
import '../../common/widgets/html/custom_html.dart';
import '../../common/widgets/html/html_chunker.dart';
import '../../utils/count_format.dart';
import '../../utils/storage.dart';
import '../../common/widgets/app_chrome.dart';
import '../../common/widgets/content_actions.dart';
import '../../services/reading_history_service.dart';

/// 问题详情页
class QuestionPage extends StatefulWidget {
  final String? questionId;

  const QuestionPage({super.key, this.questionId});

  @override
  State<QuestionPage> createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage> {
  final _loadingState = Rx<LoadingState<Map<String, dynamic>>>(const Loading());
  final _answers = <Map<String, dynamic>>[].obs;

  Map<String, dynamic>? _questionData;
  String? _questionId;
  String? _nextUrl;
  bool _isLoadingMore = false;
  final Set<String> _consumedAnswerCursors = {};
  int _loadGeneration = 0;
  bool _isDetailExpanded = false;
  late final RxString _sortBy;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments as Map<String, dynamic>?;
    _questionId = widget.questionId ?? arguments?['questionId'];
    _sortBy = RxString(Pref.defaultAnswerSort);

    // 检查缓存，实现即时渲染
    if (_questionId != null && QuestionHttp.cache.containsKey(_questionId)) {
      _questionData = QuestionHttp.cache[_questionId];
      _loadingState.value = Success(_questionData!);
      _recordHistory(_questionData!);
      // 异步加载回答列表
      _loadAnswers();
    } else {
      _loadData();
    }
  }

  /// 仅加载回答列表（问题详情已缓存时使用）
  Future<void> _loadAnswers() async {
    if (_questionId == null) return;
    final generation = ++_loadGeneration;
    _isLoadingMore = false;
    _consumedAnswerCursors.clear();

    final answersResult = await QuestionHttp.getQuestionAnswers(
      questionId: _questionId!,
      sortBy: _sortBy.value,
    );
    if (!mounted || generation != _loadGeneration) return;
    if (answersResult is Success<Map<String, dynamic>>) {
      final data = answersResult.response;
      _answers.value =
          (data['data'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
          [];
      _nextUrl = PagingInfo.fromJson(data['paging']).nextUrl;
    } else if (answersResult is Error) {
      _nextUrl = null;
      TritiumFeedback.error('回答加载失败', (answersResult as Error).errMsg);
    }
  }

  Widget _buildHtmlContent(String content, ColorScheme colorScheme) {
    return SelectionArea(
      child: CustomHtml(
        content: content,
        fontSize: 15,
        imageUrls: HtmlChunker.extractImageUrls(content),
      ),
    );
  }

  Future<void> _loadData() async {
    if (_questionId == null) {
      _loadingState.value = const Error('问题 ID 无效');
      return;
    }

    final generation = ++_loadGeneration;
    _isLoadingMore = false;
    _consumedAnswerCursors.clear();
    _loadingState.value = const Loading();

    // 加载问题详情
    final questionResult = await QuestionHttp.getQuestion(_questionId!);
    if (!mounted || generation != _loadGeneration) return;
    if (questionResult is! Success<Map<String, dynamic>>) {
      _loadingState.value = Error((questionResult as Error).errMsg);
      return;
    }
    _questionData = questionResult.response;
    _recordHistory(_questionData!);

    // 加载回答列表
    final answersResult = await QuestionHttp.getQuestionAnswers(
      questionId: _questionId!,
      sortBy: _sortBy.value,
    );
    if (!mounted || generation != _loadGeneration) return;
    if (answersResult is Success<Map<String, dynamic>>) {
      final data = answersResult.response;
      _answers.value =
          (data['data'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
          [];
      _nextUrl = PagingInfo.fromJson(data['paging']).nextUrl;
    } else if (answersResult is Error) {
      _nextUrl = null;
      TritiumFeedback.error('回答加载失败', (answersResult as Error).errMsg);
    }

    _loadingState.value = questionResult;
  }

  Future<void> _loadMore() async {
    final cursor = _nextUrl;
    if (_isLoadingMore || cursor == null) return;
    if (_consumedAnswerCursors.contains(cursor)) {
      _nextUrl = null;
      return;
    }
    final generation = _loadGeneration;
    _isLoadingMore = true;

    final result = await QuestionHttp.getQuestionAnswers(
      questionId: _questionId!,
      nextUrl: cursor,
      sortBy: _sortBy.value,
    );

    if (!mounted || generation != _loadGeneration) return;

    if (result is Success<Map<String, dynamic>>) {
      _consumedAnswerCursors.add(cursor);
      final data = result.response;
      final items =
          (data['data'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
          [];
      String? answerId(Map<String, dynamic> item) {
        final target = (item['target'] as Map<String, dynamic>?) ?? item;
        return target['id']?.toString();
      }

      final knownIds = _answers.map(answerId).whereType<String>().toSet();
      final newItems = items
          .where((item) {
            final id = answerId(item);
            return id != null && id.isNotEmpty && knownIds.add(id);
          })
          .toList(growable: false);
      _answers.addAll(newItems);

      final candidate = PagingInfo.fromJson(data['paging']).nextUrl;
      _nextUrl =
          newItems.isNotEmpty &&
              candidate != null &&
              candidate != cursor &&
              !_consumedAnswerCursors.contains(candidate)
          ? candidate
          : null;
    } else if (result is Error) {
      TritiumFeedback.error('加载失败', (result as Error).errMsg);
    }

    _isLoadingMore = false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Obx(() {
        final state = _loadingState.value;

        if (state is Loading) {
          return const Scaffold(
            appBar: TritiumBlurAppBar(title: TritiumSectionTitle('问题')),
            body: LoadingWidget(msg: '加载中...'),
          );
        }

        if (state is Error) {
          return Scaffold(
            appBar: const TritiumBlurAppBar(title: TritiumSectionTitle('问题')),
            body: custom.ErrorWidget(
              message: (state as Error).errMsg,
              onRetry: _loadData,
            ),
          );
        }

        final data = _questionData!;
        final title = data['title'] ?? '';
        final detail = data['detail'] ?? '';
        final answerCount = parseCount(data['answer_count']);
        final followerCount = parseCount(data['follower_count']);
        // 浏览量优先使用 visit_count，缺失时兼容 read_count；两者都无效显示 “—”。
        final viewCount = firstValidCount(
          data['visit_count'],
          data['read_count'],
        );

        // 计算所有回答 ID 列表，用于详情页滑动切换
        final answerIds = _answers
            .map((e) {
              final t = (e['target'] as Map<String, dynamic>?) ?? e;
              return t['id']?.toString();
            })
            .where((e) => e != null)
            .cast<String>()
            .toList();

        // 获取传递的 heroTag
        final arguments = Get.arguments as Map<String, dynamic>?;
        final heroTag = arguments?['heroTag'];

        Widget scaffoldContent = CustomScrollView(
          slivers: [
            // AppBar
            TritiumSliverAppBar(
              title: const TritiumSectionTitle('问题'),
              actions: [
                ContentActionsMenu(title: title.toString(), url: _questionUrl),
              ],
            ),
            // 问题标题
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      // 问题描述（支持折叠）
                      Builder(
                        builder: (context) {
                          // 简单的长度判定，如果内容较短则直接显示
                          final bool isLongContent = detail.length > 300;

                          if (!isLongContent) {
                            return _buildHtmlContent(detail, colorScheme);
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_isDetailExpanded)
                                _buildHtmlContent(detail, colorScheme)
                              else
                                Stack(
                                  children: [
                                    Container(
                                      height: 200,
                                      clipBehavior: Clip.hardEdge,
                                      decoration: const BoxDecoration(),
                                      child: _buildHtmlContent(
                                        detail,
                                        colorScheme,
                                      ),
                                    ),
                                    // 渐变遮罩
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      height: 80,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              colorScheme.surface.withValues(
                                                alpha: 0.0,
                                              ),
                                              colorScheme.surface,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                              // 展开/收起按钮
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isDetailExpanded = !_isDetailExpanded;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _isDetailExpanded ? '收起问题描述' : '展开阅读全文',
                                        style: TextStyle(
                                          color: colorScheme.primary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Icon(
                                        _isDetailExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        color: colorScheme.primary,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    // 统计信息
                    Row(
                      children: [
                        _StatItem(
                          label: '关注者',
                          value: formatCount(followerCount),
                        ),
                        const SizedBox(width: 24),
                        _StatItem(label: '被浏览', value: formatCount(viewCount)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 分隔线和回答数
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${answerCount == null ? '—' : formatCount(answerCount)} 个回答',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    const Spacer(),
                    // 排序按钮
                    Obx(
                      () => TextButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  title: const Text('按热度排序'),
                                  trailing: _sortBy.value == 'default'
                                      ? Icon(
                                          Icons.check,
                                          color: colorScheme.primary,
                                        )
                                      : null,
                                  onTap: () {
                                    Navigator.pop(context);
                                    if (_sortBy.value != 'default') {
                                      _sortBy.value = 'default';
                                      _loadData();
                                    }
                                  },
                                ),
                                ListTile(
                                  title: const Text('按时间排序'),
                                  trailing: _sortBy.value == 'created'
                                      ? Icon(
                                          Icons.check,
                                          color: colorScheme.primary,
                                        )
                                      : null,
                                  onTap: () {
                                    Navigator.pop(context);
                                    if (_sortBy.value != 'created') {
                                      _sortBy.value = 'created';
                                      _loadData();
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.sort,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        label: Text(
                          _sortBy.value == 'default' ? '默认排序' : '最新排序',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 回答列表
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index >= _answers.length) {
                  // 加载更多
                  _loadMore();
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                final answer = _answers[index];
                return _AnswerItem(
                  answer: answer,
                  questionId: _questionId!,
                  allAnswerIds: answerIds,
                  nextUrl: _nextUrl,
                  sortBy: _sortBy.value,
                );
              }, childCount: _answers.length + (_nextUrl != null ? 1 : 0)),
            ),
            // 底部间距
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );

        Widget body = scaffoldContent;
        // 如果有 heroTag，用 Hero 包裹 Scaffold
        if (heroTag != null && heroTag is String && heroTag.isNotEmpty) {
          body = Hero(tag: heroTag, child: scaffoldContent);
        }

        return Scaffold(body: body);
      }),
    );
  }

  String get _questionUrl =>
      'https://www.zhihu.com/question/${_questionId ?? ''}';

  void _recordHistory(Map<String, dynamic> data) {
    final id = _questionId;
    if (id == null) return;
    unawaited(
      ReadingHistoryService.record(
        kind: 'question',
        id: id,
        title: data['title']?.toString() ?? '问题',
        preview:
            data['excerpt']?.toString() ?? data['detail']?.toString() ?? '',
        url: _questionUrl,
      ),
    );
  }
}

/// 统计项
class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
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

/// 回答卡片
class _AnswerItem extends StatelessWidget {
  final Map<String, dynamic> answer;
  final String questionId;
  final List<String> allAnswerIds;
  final String? nextUrl;
  final String sortBy;

  const _AnswerItem({
    required this.answer,
    required this.questionId,
    required this.allAnswerIds,
    this.nextUrl,
    this.sortBy = 'default',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // API 返回的数据可能包裹在 target 字段中 (question_feed_card)
    final target = (answer['target'] as Map<String, dynamic>?) ?? answer;

    final author = target['author'] as Map<String, dynamic>?;
    final excerpt = target['excerpt'] ?? '';
    final voteupCount = parseCount(target['voteup_count']);
    final commentCount = parseCount(target['comment_count']);

    final authorName = author?['name'] ?? '匿名用户';
    final authorHeadline = author?['headline'] ?? '';
    final authorAvatar = author?['avatar_url'] ?? '';
    final answerId = target['id']?.toString();

    // 预加载回答详情
    if (answerId != null) {
      AnswerHttp.preload(answerId);
    }

    return InkWell(
      onTap: () {
        if (answerId != null) {
          Get.toNamed(
            Routes.answer,
            arguments: {
              'questionId': questionId,
              'answerId': answerId,
              'answerIds': allAnswerIds,
              if (nextUrl != null && nextUrl!.isNotEmpty) 'nextUrl': nextUrl,
              'sortBy': sortBy,
            },
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
            // 作者信息
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: authorAvatar.isNotEmpty
                      ? CachedNetworkImageProvider(authorAvatar)
                      : null,
                  child: authorAvatar.isEmpty
                      ? Icon(
                          Icons.person,
                          size: 16,
                          color: colorScheme.onPrimaryContainer,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (authorHeadline.isNotEmpty)
                        Text(
                          authorHeadline,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 回答摘要
            Text(
              excerpt.replaceAll(
                RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true),
                '',
              ),
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurface,
                height: 1.6,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            // 底部操作
            Row(
              children: [
                Icon(
                  Icons.thumb_up_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  formatCount(voteupCount),
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  formatCount(commentCount),
                  style: TextStyle(
                    fontSize: 13,
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
