import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../http/comment_http.dart';
import '../../http/init.dart';
import '../../models/common/paging_info.dart';
import '../widgets/error_widget.dart' as custom;
import 'app_chrome.dart';
import 'unified_comment_item.dart';

/// 子评论面板（BottomSheet 弹出）
///
/// 对标 PiliPlus 的 VideoReplyReplyPanel 实现
class ChildCommentPanel extends StatefulWidget {
  final String parentCommentId;
  final Map<String, dynamic>? parentComment; // 父评论数据，用于显示顶部

  const ChildCommentPanel({
    super.key,
    required this.parentCommentId,
    this.parentComment,
  });

  /// 显示子评论面板
  static void show(
    BuildContext context, {
    required String parentCommentId,
    Map<String, dynamic>? parentComment,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (context) => ChildCommentPanel(
        parentCommentId: parentCommentId,
        parentComment: parentComment,
      ),
    );
  }

  @override
  State<ChildCommentPanel> createState() => _ChildCommentPanelState();
}

class _ChildCommentPanelState extends State<ChildCommentPanel> {
  final _loadingState = Rx<LoadingState<Map<String, dynamic>>>(const Loading());
  final _comments = <Map<String, dynamic>>[].obs;
  String? _nextUrl;
  bool _isLoadingMore = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }

  Future<void> _loadData() async {
    final generation = ++_loadGeneration;
    _isLoadingMore = false;
    _loadingState.value = const Loading();

    final result = await CommentHttp.getRootComments(
      resourceId: widget.parentCommentId,
      resourceType: 'comment', // 子评论使用 comment 类型
      orderBy: 'ts', // 子评论按时间排序
    );

    if (!mounted || generation != _loadGeneration) return;

    if (result is Success<Map<String, dynamic>>) {
      final data = result.response;
      final items =
          (data['data'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
          [];
      _nextUrl = PagingInfo.fromJson(data['paging']).nextUrl;
      _comments.value = items;
      _loadingState.value = Success(data);
    } else if (result is Error) {
      _loadingState.value = Error((result as Error).errMsg);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _nextUrl == null) return;
    final generation = _loadGeneration;
    _isLoadingMore = true;

    final result = await CommentHttp.getRootComments(
      resourceId: widget.parentCommentId,
      resourceType: 'comment',
      nextUrl: _nextUrl,
    );

    if (!mounted || generation != _loadGeneration) return;

    if (result is Success<Map<String, dynamic>>) {
      final data = result.response;
      final items =
          (data['data'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
          [];
      _nextUrl = PagingInfo.fromJson(data['paging']).nextUrl;
      _comments.addAll(items);
    } else if (result is Error) {
      Get.snackbar('加载失败', (result as Error).errMsg);
    }

    _isLoadingMore = false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TritiumGlassSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部拖动条和标题
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  '评论详情',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  tooltip: '关闭',
                ),
              ],
            ),
          ),

          // 内容区域 (CustomScrollView)
          Expanded(
            child: Obx(() {
              final state = _loadingState.value;

              if (state is Loading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is Error) {
                return custom.ErrorWidget(
                  message: (state as Error).errMsg,
                  onRetry: _loadData,
                );
              }

              if (_comments.isEmpty && widget.parentComment == null) {
                return const Center(child: Text('暂无回复'));
              }

              return NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollEndNotification) {
                    if (notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent - 100) {
                      _loadMore();
                    }
                  }
                  return false;
                },
                child: CustomScrollView(
                  slivers: [
                    // 父评论
                    if (widget.parentComment != null)
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            UnifiedCommentItem(
                              comment: widget.parentComment!,
                              resourceId: widget.parentCommentId,
                              resourceType: 'comment',
                              showChildComments: false, // 面板顶部不显示子评论预览
                              enableRepliesNavigation: false,
                            ),
                            Divider(
                              height: 1,
                              thickness: 8,
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                      ),

                    // 子评论列表
                    if (_comments.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(child: Text('暂无回复')),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final int totalCount =
                                _comments.length * 2 -
                                1 +
                                ((_nextUrl != null) ? 1 : 0);

                            // 底部 Loading
                            if (_nextUrl != null && index == totalCount - 1) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            }

                            // 分割线
                            if (index.isOdd) {
                              return Divider(
                                height: 1,
                                thickness: 0.5,
                                indent: 56,
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.2,
                                ),
                              );
                            }

                            // 实际数据索引
                            final itemIndex = index ~/ 2;
                            if (itemIndex >= _comments.length) {
                              return const SizedBox.shrink();
                            }

                            return UnifiedCommentItem(
                              comment: _comments[itemIndex],
                              resourceId: widget.parentCommentId,
                              resourceType: 'comment',
                              showChildComments: false,
                              isChildComment: true,
                              enableRepliesNavigation: false,
                            );
                          },
                          childCount:
                              _comments.length * 2 -
                              1 +
                              ((_nextUrl != null) ? 1 : 0),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
