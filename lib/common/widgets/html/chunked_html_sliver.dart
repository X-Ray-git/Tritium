import 'package:flutter/material.dart';

import 'custom_html.dart';
import 'html_chunker.dart';

/// 长正文的 Sliver 渲染入口。
///
/// 短正文保持一次渲染；长正文先在必要时移出主 Isolate 解析，再通过 SliverList 按需
/// 构建，避免打开长文章时一次创建整棵 HTML Widget 树。
class ChunkedHtmlSliver extends StatefulWidget {
  final String content;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onReady;
  final List<String> imageUrls;

  const ChunkedHtmlSliver({
    super.key,
    required this.content,
    this.fontSize = 16,
    this.padding = EdgeInsets.zero,
    this.onReady,
    this.imageUrls = const [],
  });

  @override
  State<ChunkedHtmlSliver> createState() => _ChunkedHtmlSliverState();
}

class _ChunkedHtmlSliverState extends State<ChunkedHtmlSliver> {
  List<String> _chunks = const [];
  bool _isParsing = false;
  int _generation = 0;
  int _notifiedGeneration = -1;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant ChunkedHtmlSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) _prepare();
  }

  void _prepare() {
    final generation = ++_generation;
    if (widget.content.length < HtmlChunker.minChunkingLength) {
      _chunks = widget.content.trim().isEmpty ? const [] : [widget.content];
      _isParsing = false;
      _notifyReady(generation);
      return;
    }

    _chunks = const [];
    _isParsing = true;
    HtmlChunker.parse(widget.content)
        .then((chunks) {
          if (!mounted || generation != _generation) return;
          setState(() {
            _chunks = chunks.isEmpty ? [widget.content] : chunks;
            _isParsing = false;
          });
          _notifyReady(generation);
        })
        .catchError((Object _) {
          if (!mounted || generation != _generation) return;
          setState(() {
            _chunks = [widget.content];
            _isParsing = false;
          });
          _notifyReady(generation);
        });
  }

  void _notifyReady(int generation) {
    if (_notifiedGeneration == generation) return;
    _notifiedGeneration = generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation) widget.onReady?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isParsing) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: widget.padding,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => RepaintBoundary(
            child: CustomHtml(
              content: _chunks[index],
              fontSize: widget.fontSize,
              imageUrls: widget.imageUrls,
            ),
          ),
          childCount: _chunks.length,
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: false,
          addSemanticIndexes: true,
        ),
      ),
    );
  }
}
