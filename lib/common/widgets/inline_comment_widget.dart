import 'package:flutter/material.dart';

import '../../http/comment_http.dart';
import '../../http/init.dart';
import '../../utils/storage.dart';
import 'unified_comment_item.dart';

/// 内联评论组件
/// 
/// 用于在回答/文章/想法详情页中嵌入显示评论列表
/// 参考 PiliPlus 的 dynamics_detail 设计
class InlineCommentWidget extends StatefulWidget {
  /// 资源 ID（回答/文章/想法 ID）
  final String resourceId;
  
  /// 资源类型：answers, articles, pins
  final String resourceType;
  
  /// 初始显示的评论数量
  final int initialCount;
  
  /// 是否显示标题
  final bool showHeader;

  const InlineCommentWidget({
    super.key,
    required this.resourceId,
    required this.resourceType,
    this.initialCount = 10,
    this.showHeader = true,
  });

  @override
  State<InlineCommentWidget> createState() => _InlineCommentWidgetState();
}

class _InlineCommentWidgetState extends State<InlineCommentWidget> with AutomaticKeepAliveClientMixin {
  final List<dynamic> _comments = [];
  String? _nextUrl;
  int _totalCount = 0;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMsg = '';
  late String _orderBy;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _orderBy = Pref.defaultCommentSort;
    _loadData();
  }

  Future<void> _loadData({bool loadMore = false}) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    dynamic result;
    if (loadMore && _nextUrl != null) {
      result = await CommentHttp.getRootComments(
        resourceId: widget.resourceId,
        resourceType: widget.resourceType,
        nextUrl: _nextUrl,
      );
    } else {
      result = await CommentHttp.getRootComments(
        resourceId: widget.resourceId,
        resourceType: widget.resourceType,
        orderBy: _orderBy,
      );
    }

    if (!mounted) return;

    if (result is Success<Map<String, dynamic>>) {
      final data = result.response;
      final paging = data['paging'] as Map<String, dynamic>?;
      final counts = data['counts'] as Map<String, dynamic>?;
      final commonCounts = data['common_counts'] as Map<String, dynamic>?;

      _nextUrl = (paging != null && paging['is_end'] == false) 
          ? paging['next'] 
          : null;
      
      if (!loadMore) {
        _totalCount = counts?['total_counts'] ?? commonCounts?['total_counts'] ?? 0;
        _comments.clear();
      }

      final List<dynamic> newComments = data['data'] ?? [];
      _comments.addAll(newComments);

      setState(() {
        _isLoading = false;
      });
    } else if (result is Error) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMsg = (result as Error).errMsg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 评论区标题
        if (widget.showHeader)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: 8,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '评论',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_totalCount',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                // 排序按钮
                TextButton.icon(
                  onPressed: _showSortOptions,
                  icon: Icon(
                    Icons.sort_rounded, 
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  label: Text(
                    _orderBy == 'score' ? '按热度' : '按时间',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // 评论列表
        if (_hasError)
          _buildErrorWidget()
        else if (_isLoading && _comments.isEmpty)
          _buildLoadingWidget()
        else if (_comments.isEmpty)
          _buildEmptyWidget()
        else
          ..._buildCommentList(),
        
        // 加载更多
        if (_nextUrl != null && !_isLoading)
          _buildLoadMoreButton(),
        
        // 底部间距
        const SizedBox(height: 20),
      ],
    );
  }

  void _showSortOptions() {
    final colorScheme = Theme.of(context).colorScheme;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('按热度排序'),
            trailing: _orderBy == 'score' 
                ? Icon(Icons.check, color: colorScheme.primary) 
                : null,
            onTap: () {
              Navigator.pop(context);
              if (_orderBy != 'score') {
                _orderBy = 'score';
                _loadData();
              }
            },
          ),
          ListTile(
            title: const Text('按时间排序'),
            trailing: _orderBy == 'ts' 
                ? Icon(Icons.check, color: colorScheme.primary) 
                : null,
            onTap: () {
              Navigator.pop(context);
              if (_orderBy != 'ts') {
                _orderBy = 'ts';
                _loadData();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Text(_errorMsg, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadData,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text('暂无评论', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  List<Widget> _buildCommentList() {
    return _comments.map((comment) {
      return UnifiedCommentItem(
        comment: comment,
        resourceId: widget.resourceId,
        resourceType: widget.resourceType,
      );
    }).toList();
  }

  Widget _buildLoadMoreButton() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _loadData(loadMore: true),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '查看更多评论',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
