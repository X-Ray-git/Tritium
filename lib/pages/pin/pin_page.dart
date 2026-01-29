import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../http/content_http.dart';
import '../../http/init.dart';
import '../../common/widgets/loading_widget.dart';
import '../../common/widgets/error_widget.dart' as custom;

import '../../common/widgets/html/custom_html.dart';
import '../../common/widgets/inline_comment_widget.dart';

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

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments as Map<String, dynamic>?;
    _pinId = widget.pinId ?? arguments?['pinId'];
    
    // 同步检查缓存
    if (_pinId != null && PinHttp.cache.containsKey(_pinId)) {
      _pinData = PinHttp.cache[_pinId];
      _loadingState.value = Success(_pinData!);
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_pinId == null) {
      _loadingState.value = const Error('想法 ID 无效');
      return;
    }

    if (_loadingState.value is! Success) {
       _loadingState.value = const Loading();
    }

    final result = await PinHttp.getPin(_pinId!);

    if (result is Success<Map<String, dynamic>>) {
      _pinData = result.response;
      _loadingState.value = result;
    } else if (result is Error) {
      _loadingState.value = Error((result as Error).errMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('想法详情')),
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

        // 图片列表 handled by CustomHtml or separate grid? 
        List<String> imageUrls = [];
        if (data['content'] != null && data['content'] is List) {
           for (var item in data['content']) {
              if (item['type'] == 'image' || item['type'] == 'video') {
                 if (item['url'] != null) imageUrls.add(item['url']);
              }
           }
        }

        return ListView(
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
                   content: contentRaw is String ? contentRaw : contentRaw.toString(),
                   fontSize: 17,
                 ),
               ),
             
             const SizedBox(height: 16),
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16),
               child: Row(
                 children: [
                   Icon(Icons.thumb_up_outlined, size: 20, color: colorScheme.secondary),
                   const SizedBox(width: 8),
                   Text('$voteupCount 赞同', style: TextStyle(color: colorScheme.secondary)),
                   const SizedBox(width: 24),
                   Icon(Icons.chat_bubble_outline, size: 20, color: colorScheme.secondary),
                   const SizedBox(width: 8),
                   Text('$commentCount 评论', style: TextStyle(color: colorScheme.secondary)),
                 ],
               ),
             ),
             
             // 评论区（嵌入在想法内容下方）
             if (_pinId != null)
               InlineCommentWidget(
                 resourceId: _pinId!,
                 resourceType: 'pins',
                 showHeader: true,
               ),
               
             const SizedBox(height: 100),
          ],
        );
      }),
    );
  }
}
