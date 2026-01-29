import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../http/comment_http.dart';
import '../../http/init.dart';
import '../../common/widgets/loading_widget.dart';
import '../../common/widgets/error_widget.dart' as custom;
import '../../common/widgets/unified_comment_item.dart';
import '../../utils/storage.dart';

/// 统一评论页面
/// 
/// 适用于回答、想法、专栏等内容的评论展示
/// 采用了 PiliPlus 风格的紧凑设计：左侧头像，右侧内容
class CommentPage extends StatefulWidget {
  const CommentPage({super.key});

  @override
  State<CommentPage> createState() => _UnifiedCommentPageState();
}

class _UnifiedCommentPageState extends State<CommentPage> {
  final _loadingState = Rx<LoadingState<List<dynamic>>>(const Loading());
  final List<dynamic> _comments = [];
  String? _nextUrl;
  
  late String _resourceId;
  late String _resourceType;
  final _totalCounts = 0.obs;
  late final RxString _orderBy;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    _resourceId = args?['id'] ?? '';
    _resourceType = args?['type'] ?? 'answers'; // answers, articles, pins
    _orderBy = RxString(Pref.defaultCommentSort);
    _loadData();
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    if (isRefresh) {
      _loadingState.value = const Loading();
      _comments.clear();
      _nextUrl = null;
    }

    dynamic result;
    if (_nextUrl != null) {
      result = await CommentHttp.getRootComments(
        resourceId: _resourceId, 
        resourceType: _resourceType, 
        nextUrl: _nextUrl
      );
    } else {
      result = await CommentHttp.getRootComments(
        resourceId: _resourceId, 
        resourceType: _resourceType, 
        orderBy: _orderBy.value,
      );
    }

    if (result is Success<Map<String, dynamic>>) {
      final data = result.response;
      final paging = data['paging'] as Map<String, dynamic>?;
      final counts = data['counts'] as Map<String, dynamic>?;
      final commonCounts = data['common_counts'] as Map<String, dynamic>?;
      
      _nextUrl = (paging != null && paging['is_end'] == false) ? paging['next'] : null;
      _totalCounts.value = counts?['total_counts'] ?? commonCounts?['total_counts'] ?? 0;
      
      final List<dynamic> newComments = data['data'] ?? [];
      _comments.addAll(newComments);
      
      _loadingState.value = Success(_comments);
    } else if (result is Error) {
      if (_comments.isEmpty) {
        _loadingState.value = Error(result.errMsg);
      } else {
        Get.snackbar('加载失败', result.errMsg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text('评论 (${_totalCounts.value})')),
        actions: [
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('按热度排序'),
                      trailing: _orderBy.value == 'score' ? Icon(Icons.check, color: colorScheme.primary) : null,
                      onTap: () {
                        Navigator.pop(context);
                        if (_orderBy.value != 'score') {
                          _orderBy.value = 'score';
                          _loadData(isRefresh: true);
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('按时间排序'),
                      trailing: _orderBy.value == 'ts' ? Icon(Icons.check, color: colorScheme.primary) : null,
                      onTap: () {
                        Navigator.pop(context);
                        if (_orderBy.value != 'ts') {
                          _orderBy.value = 'ts';
                          _loadData(isRefresh: true);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.sort_rounded),
            tooltip: '排序',
          ),
        ],
      ),
      body: Obx(() {
        final state = _loadingState.value;
        
        if (state is Loading && _comments.isEmpty) {
          return const LoadingWidget(msg: '加载评论中...');
        }
        
        if (state is Error && _comments.isEmpty) {
          return custom.ErrorWidget(
            message: (state as Error).errMsg,
            onRetry: () => _loadData(isRefresh: true),
          );
        }

        return RefreshIndicator(
          onRefresh: () => _loadData(isRefresh: true),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: _comments.length + (_nextUrl != null ? 1 : 0),
            separatorBuilder: (context, index) => Divider(
              height: 1, 
              thickness: 0.5, 
              indent: 56, // 左侧留出头像空间，分割线只在内容下方
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
            itemBuilder: (context, index) {
              if (index == _comments.length) {
                _loadData(); // Load more
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              
              final comment = _comments[index];
              return UnifiedCommentItem(
                comment: comment,
                resourceId: _resourceId,
                resourceType: _resourceType,
              );
            },
          ),
        );
      }),
    );
  }
}
