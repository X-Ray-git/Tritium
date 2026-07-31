import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../http/content_http.dart';
import '../../http/init.dart';
import '../../common/widgets/loading_widget.dart';
import '../../common/widgets/error_widget.dart' as custom;

import '../../common/widgets/html/custom_html.dart';
import '../../common/widgets/html/html_chunker.dart';
import '../../common/widgets/inline_comment_widget.dart';
import '../../common/widgets/app_chrome.dart';
import '../../common/widgets/content_actions.dart';
import '../../common/widgets/reading_progress.dart';
import '../../services/reading_history_service.dart';
import '../../utils/comment_preload.dart';

/// 想法（Pin）详情页
class PinPage extends StatefulWidget {
  final String? pinId;

  const PinPage({super.key, this.pinId});

  @override
  State<PinPage> createState() => _PinPageState();
}

class _PinPageState extends State<PinPage> {
  final _loadingState = Rx<LoadingState<Map<String, dynamic>>>(const Loading());
  Map<String, dynamic>? _pinData;
  String? _pinId;
  int _loadGeneration = 0;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _bodyEndKey = GlobalKey();
  ReadingSession? _readingSession;
  bool _contentReady = false;
  bool _showComments = false;
  ScrollMetrics? _lastScrollMetrics;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments as Map<String, dynamic>?;
    _pinId = widget.pinId ?? arguments?['pinId'];
    if (_pinId != null) {
      _readingSession = ReadingSession(
        kind: 'pin',
        id: _pinId!,
        scrollController: _scrollController,
        bodyEndKey: _bodyEndKey,
      );
    }

    // 同步检查缓存
    if (_pinId != null && PinHttp.cache.containsKey(_pinId)) {
      _pinData = PinHttp.cache[_pinId];
      _loadingState.value = Success(_pinData!);
      _contentLoaded(_pinData!);
    } else {
      _loadData();
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _readingSession?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_pinId == null) {
      _loadingState.value = const Error('想法 ID 无效');
      return;
    }

    final generation = ++_loadGeneration;
    if (_loadingState.value is! Success) {
      _loadingState.value = const Loading();
    }

    final result = await PinHttp.getPin(_pinId!);
    if (!mounted || generation != _loadGeneration) return;

    if (result is Success<Map<String, dynamic>>) {
      _pinData = result.response;
      _loadingState.value = result;
      _contentLoaded(_pinData!);
    } else if (result is Error) {
      _loadingState.value = Error((result as Error).errMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: TritiumBlurAppBar(
        title: const TritiumSectionTitle('想法'),
        actions: [ContentActionsMenu(title: '想法', url: _pinUrl)],
      ),
      body: Obx(() {
        final state = _loadingState.value;

        if (state is Loading) {
          return const LoadingWidget(msg: '加载中...');
        }

        if (state is Error) {
          return custom.ErrorWidget(
            message: (state as Error).errMsg,
            onRetry: _loadData,
          );
        }

        final data = _pinData!;

        final contentRaw = data['content_html'] ?? data['content'] ?? '';
        final author = data['author'] as Map<String, dynamic>?;
        final voteupCount = data['voteup_count'] ?? 0;
        final commentCount = data['comment_count'] ?? 0;
        // createdTime 这里暂不使用
        // final createdTime = data['created'] as int?;

        final authorName = author?['name'] ?? '匿名用户';
        final authorHeadline = author?['headline'] ?? '';
        final authorAvatar = author?['avatar_url'] ?? '';

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis == Axis.vertical) {
              _lastScrollMetrics = notification.metrics;
              _maybeShowComments();
            }
            return false;
          },
          child: ListView(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            children: [
              // Author info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: colorScheme.primaryContainer,
                      backgroundImage: authorAvatar.isNotEmpty
                          ? CachedNetworkImageProvider(authorAvatar)
                          : null,
                      child: authorAvatar.isEmpty
                          ? Icon(
                              Icons.person,
                              color: colorScheme.onPrimaryContainer,
                            )
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              if (contentRaw.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CustomHtml(
                    content: contentRaw is String
                        ? contentRaw
                        : contentRaw.toString(),
                    fontSize: 17,
                    imageUrls: HtmlChunker.extractImageUrls(
                      contentRaw is String ? contentRaw : contentRaw.toString(),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.thumb_up_outlined,
                      size: 20,
                      color: colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$voteupCount 赞同',
                      style: TextStyle(color: colorScheme.secondary),
                    ),
                    const SizedBox(width: 24),
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 20,
                      color: colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$commentCount 评论',
                      style: TextStyle(color: colorScheme.secondary),
                    ),
                  ],
                ),
              ),

              // 评论区（嵌入在想法内容下方）
              SizedBox(key: _bodyEndKey),
              if (_showComments && _pinId != null)
                InlineCommentWidget(
                  resourceId: _pinId!,
                  resourceType: 'pins',
                  showHeader: true,
                ),

              const SizedBox(height: 100),
            ],
          ),
        );
      }).withTritiumReadingSession(_readingSession),
    );
  }

  String get _pinUrl => 'https://www.zhihu.com/pin/${_pinId ?? ''}';

  void _contentLoaded(Map<String, dynamic> data) {
    final id = _pinId;
    if (id == null) return;
    final author = data['author'];
    final authorName = author is Map ? author['name']?.toString() : null;
    final content = data['content_html'] ?? data['content'] ?? '';
    unawaited(
      ReadingHistoryService.record(
        kind: 'pin',
        id: id,
        title: authorName == null || authorName.isEmpty
            ? '想法'
            : '$authorName 的想法',
        preview: content.toString(),
        url: _pinUrl,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _contentReady = true;
      _readingSession?.contentReady();
      _maybeShowComments();
    });
  }

  void _maybeShowComments() {
    if (!mounted || _showComments || !_contentReady) return;
    final anchorBox =
        _bodyEndKey.currentContext?.findRenderObject() as RenderBox?;
    final anchorTop = anchorBox != null && anchorBox.hasSize
        ? anchorBox.localToGlobal(Offset.zero).dy
        : null;
    if (!shouldPreloadComments(
      anchorTop: anchorTop,
      viewportHeight: MediaQuery.sizeOf(context).height,
      extentAfter: _lastScrollMetrics?.extentAfter,
    )) {
      return;
    }
    _readingSession?.refresh();
    setState(() => _showComments = true);
  }
}
