import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../http/comment_http.dart';
import '../../http/init.dart';
import 'unified_comment_item.dart';
import 'child_comment_panel.dart';
import 'loading_widget.dart';
import 'error_widget.dart' as custom;

/// 对话查看面板
/// 
/// 仅向上回溯对话链，显示祖先评论和当前评论
class ConversationPanel extends StatefulWidget {
  final Map<String, dynamic> startComment;
  final String resourceType; // 'comment' for now
  
  const ConversationPanel({
    super.key, 
    required this.startComment,
    this.resourceType = 'comment',
  });

  static void show(BuildContext context, {required Map<String, dynamic> startComment}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ConversationPanel(startComment: startComment),
    );
  }

  @override
  State<ConversationPanel> createState() => _ConversationPanelState();
}

class _ConversationPanelState extends State<ConversationPanel> {
  // State - 只保留祖先链
  final _ancestors = <Map<String, dynamic>>[].obs;
  late Map<String, dynamic> _focusComment;
  
  // Loading Status
  final _isLoading = true.obs;
  final _errorMsg = RxnString();

  @override
  void initState() {
    super.initState();
    _focusComment = widget.startComment;
    _loadAncestors();
  }

  /// 加载祖先链 (向上递归)
  Future<void> _loadAncestors() async {
    _isLoading.value = true;
    _errorMsg.value = null;
    _ancestors.clear();
    
    // 1. 初始化链条
    List<Map<String, dynamic>> chain = [];
    
    try {
      Map<String, dynamic> current = _focusComment;
      int depthLimit = 10; // 防止无限循环
      int currentDepth = 0;

      // 2. 向上回溯
      while (currentDepth < depthLimit) {
        final replyId = current['reply_comment_id']?.toString();
        if (replyId == null || replyId == '0' || replyId.isEmpty) {
          break;
        }
        
        // 防止环
        if (chain.any((c) => c['id'].toString() == replyId)) {
          break;
        }

        final result = await CommentHttp.getComment(replyId);
        
        if (result is Success<Map<String, dynamic>>) {
          final parent = result.response;
          chain.insert(0, parent); // 插入头部
          current = parent;
        } else {
          break;
        }
        
        currentDepth++;
      }
      
      _ancestors.value = chain;

    } catch (e) {
      _errorMsg.value = e.toString();
      debugPrint('Ancestors load failed: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // 根据内容动态调整高度，最小 300，最大 85% 屏幕高度
    final size = MediaQuery.of(context).size;

    return Container(
      constraints: BoxConstraints(
        minHeight: 300,
        maxHeight: size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部 Handle
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                Text(
                  '查看对话',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // 内容区
          Expanded(
            child: Obx(() {
              if (_isLoading.value) {
                return const Center(
                  child: LoadingWidget(msg: '加载对话中...'),
                );
              }
              
              if (_errorMsg.value != null && _ancestors.isEmpty) {
                return custom.ErrorWidget(
                  message: _errorMsg.value!,
                  onRetry: _loadAncestors,
                );
              }

              // 合并祖先链 + 焦点评论
              final allComments = [..._ancestors, _focusComment];
              
              if (allComments.length == 1) {
                // 只有当前评论，没有祖先
                return Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          '这是对话的起点',
                          style: TextStyle(color: colorScheme.outline, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _loadAncestors,
                child: ListView.builder(
                  itemCount: allComments.length,
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final item = allComments[index];
                    final isFocus = index == allComments.length - 1;
                    final hasConnector = index < allComments.length - 1;
                    
                    return _buildItem(item, isFocus: isFocus, hasConnector: hasConnector);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item, {required bool isFocus, required bool hasConnector}) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Stack(
      children: [
        Container(
          color: isFocus 
              ? colorScheme.primaryContainer.withValues(alpha: 0.15) 
              : null,
          child: UnifiedCommentItem(
            comment: item,
            resourceId: '', 
            resourceType: 'comment',
            isChildComment: true, 
            showChildComments: false, 
            showViewConversation: false,
            onReplyTap: () {
               Get.to(() => ChildCommentPanel(
                parentCommentId: item['id'].toString(), 
                resourceType: 'comment',
                parentComment: item,
               ));
            },
          ),
        ),
        
        // 连接线 - 显示在每个非焦点评论下方
        if (hasConnector)
           Positioned(
              left: 32, 
              top: 60,
              bottom: 0,
              width: 2,
              child: Container(
                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
      ],
    );
  }
}
