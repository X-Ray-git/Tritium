import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:html/dom.dart' as dom;

import '../../../services/content_link_service.dart';
import '../../widgets/feedback_toast.dart';
import '../image_viewer.dart';

/// 统一的 HTML 渲染组件
///
/// 支持 LaTeX 公式 (math_fork)、正文图片点击查看、行内代码与整行代码块、
/// 表格横向滚动、普通链接与应用内链接服务打通。普通 `<a href>` 保留
/// flutter_html 的嵌套结构与文字选择能力，只有评论“查看图片/动图”链接使用
/// 专用缩略图扩展。
class CustomHtml extends StatelessWidget {
  final String content;
  final ColorScheme? colorScheme;
  final double fontSize;
  final EdgeInsetsGeometry? padding;
  final List<String> imageUrls;

  /// 链接点击处理器；默认交给 [ContentLinkService.open]。
  final void Function(
    String? url,
    Map<String, String> attributes,
    dom.Element? element,
  )?
  onLinkTap;

  const CustomHtml({
    super.key,
    required this.content,
    this.colorScheme,
    this.fontSize = 16.0,
    this.padding,
    this.imageUrls = const [],
    this.onLinkTap,
  });

  static const _emojiMap = {
    '握手': 'https://pic2.zhimg.com/v2-f5aa165e86b5c9ed3b7bee821da59365.png',
    '打招呼': 'https://picx.zhimg.com/v2-95c560d0c9c0491f6ef404cc010878fc.png',
    '哇': 'https://picx.zhimg.com/v2-6a766571a6d6d3a4d8d16f433e5b284c.png',
    '感谢': 'https://pic1.zhimg.com/v2-694cac2ec9f3c63f774e723f77d8c840.png',
    '知乎益蜂': 'https://pica.zhimg.com/v2-11d9b8b6edaae71e992f95007c777446.png',
    '百分百赞': 'https://picx.zhimg.com/v2-27521d5ba23dfc1ea58fd9ebb220e304.png',
    '为爱发乎': 'https://pic1.zhimg.com/v2-609b1f168acfa22d59fa09d3cb0846ee.png',
    '脑爆': 'https://pica.zhimg.com/v2-b6f53e9726998343e7713f564a422575.png',
    '暗中学习': 'https://pica.zhimg.com/v2-5dc88b4f8cbc58d7597e2134a384e392.png',
    '匿了': 'https://pic1.zhimg.com/v2-c1e799b8357888525ec45793e8270306.png',
    '谢邀': 'https://pic2.zhimg.com/v2-6fe2283baa639ae1d7c024487f1d68c7.png',
    '赞同': 'https://pic2.zhimg.com/v2-419a1a3ed02b7cfadc20af558aabc897.png',
    '蹲': 'https://pic4.zhimg.com/v2-66e5de3da039ac969d3b9d4dc5ef3536.png',
    '爱': 'https://pic1.zhimg.com/v2-0942128ebfe78f000e84339fbb745611.png',
    '害羞': 'https://pic4.zhimg.com/v2-52f8c87376792e927b6cf0896b726f06.png',
    '好奇': 'https://pic2.zhimg.com/v2-72b9696632f66e05faaca12f1f1e614b.png',
    '思考': 'https://pic4.zhimg.com/v2-bffb2bf11422c5ef7d8949788114c2ab.png',
    '酷': 'https://pic4.zhimg.com/v2-c96dd18b15beb196b2daba95d26d9b1c.png',
    '大笑': 'https://pic1.zhimg.com/v2-3ac403672728e5e91f5b2d3c095e415a.png',
    '微笑': 'https://pic1.zhimg.com/v2-3700cc07f14a49c6db94a82e989d4548.png',
    '捂脸': 'https://pic1.zhimg.com/v2-b62e608e405aeb33cd52830218f561ea.png',
    '捂嘴': 'https://pic4.zhimg.com/v2-0e26b4bbbd86a0b74543d7898fab9f6a.png',
    '飙泪笑': 'https://pic4.zhimg.com/v2-3bb879be3497db9051c1953cdf98def6.png',
    '耶': 'https://pic2.zhimg.com/v2-f3b3b8756af8b42bd3cb534cbfdbe741.png',
    '可怜': 'https://pic1.zhimg.com/v2-aa15ce4a2bfe1ca54c8bb6cc3ea6627b.png',
    '惊喜': 'https://pic2.zhimg.com/v2-3846906ea3ded1fabbf1a98c891527fb.png',
    '流泪': 'https://pic4.zhimg.com/v2-dd613c7c81599bcc3085fc855c752950.png',
    '大哭': 'https://pic1.zhimg.com/v2-41f74f3795489083630fa29fde6c1c4d.png',
    '生气': 'https://pic4.zhimg.com/v2-6a976b21fd50b9535ab3e5b17c17adc7.png',
    '惊讶': 'https://pic4.zhimg.com/v2-0d9811a7961c96d84ee6946692a37469.png',
    '调皮': 'https://pic1.zhimg.com/v2-76c864a7fd5ddc110965657078812811.png',
    '衰': 'https://pic1.zhimg.com/v2-d6d4d1689c2ce59e710aa40ab81c8f60.png',
    '发呆': 'https://pic2.zhimg.com/v2-7f09d05d34f03eab99e820014c393070.png',
    '机智': 'https://pic1.zhimg.com/v2-4e025a75f219cf79f6d1fda7726e297f.png',
    '嘘': 'https://pic4.zhimg.com/v2-f80e1dc872d68d4f0b9ac76e8525d402.png',
    '尴尬': 'https://pic3.zhimg.com/v2-b779f7eb3eac05cce39cc33e12774890.png',
    '小情绪': 'https://pic3.zhimg.com/v2-b779f7eb3eac05cce39cc33e12774890.png',
    '为难': 'https://pic1.zhimg.com/v2-132ab52908934f6c3cd9166e51b99f47.png',
    '吃瓜': 'https://pic4.zhimg.com/v2-74ecc4b114fce67b6b42b7f602c3b1d6.png',
    '语塞': 'https://pic2.zhimg.com/v2-58e3ec448b58054fde642914ebb850f9.png',
    '看看你': 'https://pic3.zhimg.com/v2-4e4870fc6e57bb76e7e5924375cb20b6.png',
    '撇嘴': 'https://pic2.zhimg.com/v2-1043b00a7b5776e2e6e1b0af2ab7445d.png',
    '魔性笑': 'https://pic2.zhimg.com/v2-e6270881e74c90fc01994e8cd072bd3a.png',
    '潜水': 'https://pic1.zhimg.com/v2-99bb6a605b136b95e442f5b69efa2ccc.png',
    '口罩': 'https://pic4.zhimg.com/v2-6551348276afd1eaf836551b93a94636.png',
    '开心': 'https://pic2.zhimg.com/v2-c99cdc3629ff004f83ff44a952e5b716.png',
    '滑稽': 'https://pic4.zhimg.com/v2-8a8f1403a93ddd0a458bed730bebe19b.png',
    '笑哭': 'https://pic4.zhimg.com/v2-ca0015e8ed8462cfce839fba518df585.png',
    '白眼': 'https://pic2.zhimg.com/v2-d4f78d92922632516769d3f2ce055324.png',
    '红心': 'https://pic2.zhimg.com/v2-9ab384e3947547851cb45765e6fc1ea8.png',
    '柠檬': 'https://pic4.zhimg.com/v2-a8f46a21217d58d2b4cdabc4568fde15.png',
    '拜托': 'https://pic2.zhimg.com/v2-3e36d546a9454c8964fbc218f0db1ff8.png',
    '赞': 'https://pic1.zhimg.com/v2-c71427010ca7866f9b08c37ec20672e0.png',
    '发火': 'https://pic1.zhimg.com/v2-d5c0ed511a09bf5ceb633387178e0d30.png',
    '不抬杠': 'https://pic4.zhimg.com/v2-395d272d5635143119b1dbc0b51e05e4.png',
    '种草': 'https://pic2.zhimg.com/v2-cb191a92f1296e33308b2aa16f61bfb9.png',
    '抱抱': 'https://pic2.zhimg.com/v2-b2e3fa9e0b6f431bd18d4a9d5d3c6596.png',
    'doge': 'https://pic4.zhimg.com/v2-501ff2e1fb7cf3f9326ec5348dc8d84f.png',
  };

  static String? emojiUrl(String name) => _emojiMap[name];

  String _processContent(String content) {
    // 替换 <span class="ztext-math">...</span> 为 <tex-math>...</tex-math>
    String processed = content.replaceAllMapped(
      RegExp(r'<span class="ztext-math"(.*?)>(.*?)</span>', dotAll: true),
      (match) => '<tex-math${match.group(1)}>${match.group(2)}</tex-math>',
    );

    // 替换表情 [Emoji] -> <img ...>
    _emojiMap.forEach((key, url) {
      if (processed.contains('[$key]')) {
        processed = processed.replaceAll(
          '[$key]',
          '<img src="$url" alt="[$key]" class="emoji" style="display:inline; width:20px; height:20px; vertical-align:middle; margin: 0 2px;" data-is-emoji="true" />',
        );
      }
    });

    return processed;
  }

  void _handleLinkTap(
    String? url,
    Map<String, String> attributes,
    dom.Element? element,
  ) {
    final customHandler = onLinkTap;
    if (customHandler != null) {
      customHandler(url, attributes, element);
      return;
    }
    final value = url?.trim() ?? '';
    // 页内 anchor 由 flutter_html 先尝试定位；未命中时不再交给浏览器或链接服务。
    if (value.isEmpty || value.startsWith('#')) return;
    ContentLinkService.open(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = colorScheme ?? theme.colorScheme;

    final renderedContent = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Html(
        data: _processContent(content),
        onLinkTap: _handleLinkTap,
        extensions: [
          // 处理 LaTeX 公式
          TagExtension(
            tagsToExtend: {"tex-math"},
            builder: (ctx) {
              String tex =
                  ctx.attributes['data-tex'] ?? ctx.element?.text ?? '';

              tex = tex
                  .replaceAll('&amp;', '&')
                  .replaceAll('&lt;', '<')
                  .replaceAll('&gt;', '>')
                  .replaceAll(r'\\', r'\')
                  .replaceAll(RegExp(r'\\tag\{.*?\}'), '')
                  .replaceAll(RegExp(r'\\label\{.*?\}'), '')
                  .replaceAll(RegExp(r'\\mbox\{.*?\}'), '')
                  .replaceAll(r'\rm ', '')
                  .trim();

              final currentFontSize = ctx.style?.fontSize?.value ?? fontSize;
              final currentColor = ctx.style?.color ?? cs.onSurface;

              return Math.tex(
                tex,
                textStyle: TextStyle(
                  fontSize: currentFontSize,
                  color: currentColor,
                ),
                mathStyle: MathStyle.text,
                onErrorFallback: (err) {
                  return Text(tex, style: TextStyle(color: cs.error));
                },
              );
            },
          ),
          // 正文图片
          _ArticleImageExtension(imageUrls: imageUrls, fontSize: fontSize),
          // 评论“查看图片/动图”缩略图链接
          _CommentImageLinkExtension(colorScheme: cs, imageUrls: imageUrls),
          // 引用块：圆角容器 + 左侧强调边框，内部保留链接与行内样式
          _BlockquoteExtension(colorScheme: cs),
          // 整行代码块
          _CodeBlockExtension(),
          // 行内代码
          InlineCodeExtension(colorScheme: cs),
          // 表格（宽表可横向滚动）
          _ArticleTableExtension(),
        ],
        style: {
          'body': Style(
            fontSize: FontSize(fontSize),
            lineHeight: const LineHeight(1.7),
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            color: cs.onSurface,
          ),
          // flutter_html defaults to 40 px on both sides of <figure>.
          // Auto Folo unwraps figure elements before rendering, so remove that
          // browser-style gutter while retaining vertical reading rhythm.
          'figure': Style(
            margin: Margins.symmetric(vertical: 12),
            padding: HtmlPaddings.zero,
          ),
          'p': Style(margin: Margins.only(bottom: 14)),
          'h1': Style(
            fontSize: FontSize(22),
            fontWeight: FontWeight.w700,
            lineHeight: const LineHeight(1.35),
            margin: Margins.only(top: 24, bottom: 10),
          ),
          'h2': Style(
            fontSize: FontSize(20),
            fontWeight: FontWeight.w700,
            lineHeight: const LineHeight(1.4),
            margin: Margins.only(top: 22, bottom: 8),
          ),
          'h3': Style(
            fontSize: FontSize(18),
            fontWeight: FontWeight.w600,
            lineHeight: const LineHeight(1.45),
            margin: Margins.only(top: 20, bottom: 8),
          ),
          'h4': Style(
            fontSize: FontSize(17),
            fontWeight: FontWeight.w600,
            lineHeight: const LineHeight(1.5),
            margin: Margins.only(top: 18, bottom: 8),
          ),
          'noscript': Style(display: Display.none),
          'a': Style(color: cs.primary, textDecoration: TextDecoration.none),
          'strong': Style(fontWeight: FontWeight.w700),
          'em': Style(fontStyle: FontStyle.italic),
          'blockquote': Style(
            fontSize: FontSize(fontSize - 1),
            color: cs.onSurfaceVariant,
          ),
          'code': Style(
            fontFamily: 'monospace',
            fontFamilyFallback: const [
              'Menlo',
              'Monaco',
              'Courier New',
              'Courier',
            ],
            fontSize: FontSize(14),
            color: cs.onSurface,
          ),
          'pre': Style(margin: Margins.symmetric(vertical: 12)),
          'ul': Style(
            padding: HtmlPaddings.only(left: 20),
            margin: Margins.only(bottom: 14),
          ),
          'ol': Style(
            padding: HtmlPaddings.only(left: 20),
            margin: Margins.only(bottom: 14),
          ),
          // 针对公式 span 的自定义样式
          'tex-math': Style(fontSize: FontSize(fontSize)),
          'hr': Style(
            margin: Margins.symmetric(vertical: 24),
            height: Height(1),
            backgroundColor: cs.outlineVariant,
            border: Border.all(style: BorderStyle.none),
          ),
        },
      ),
    );
    return _SelectionCompatibleLinkTapRegion(child: renderedContent);
  }

  static double? _parseDimension(String? value) {
    if (value == null) return null;
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
  }

  static double? _parseStyleDimension(String? style, String property) {
    if (style == null || style.isEmpty) return null;
    final match = RegExp(
      '(?:max-$property|$property)\\s*:\\s*(\\d+(?:\\.\\d+)?)\\s*px',
      caseSensitive: false,
    ).firstMatch(style);
    return match == null ? null : double.tryParse(match.group(1)!);
  }
}

/// [SelectionArea] 让 RenderParagraph 进入选择命中模式后，不再把 pointer 加入
/// TextSpan 自带的 TapGestureRecognizer。这个区域从同一次 pointer hit-test 中找到
/// 实际命中的 RenderParagraph 与 InlineSpan，只在短距离单击时补发链接动作。
class _SelectionCompatibleLinkTapRegion extends StatefulWidget {
  final Widget child;

  const _SelectionCompatibleLinkTapRegion({required this.child});

  @override
  State<_SelectionCompatibleLinkTapRegion> createState() =>
      _SelectionCompatibleLinkTapRegionState();
}

class _SelectionCompatibleLinkTapRegionState
    extends State<_SelectionCompatibleLinkTapRegion> {
  int? _pointer;
  Offset? _origin;
  Timer? _tapTimer;
  bool _tapExpired = false;
  bool _moved = false;

  void _reset() {
    _pointer = null;
    _origin = null;
    _tapTimer?.cancel();
    _tapTimer = null;
    _tapExpired = false;
    _moved = false;
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  void _invokeLinkAt(Offset globalPosition) {
    // Outside SelectionArea, flutter_html's normal TapGestureRecognizer owns
    // the click and provides native semantics; no fallback is needed.
    if (SelectionContainer.maybeOf(context) == null) return;

    final result = HitTestResult();
    RendererBinding.instance.hitTestInView(
      result,
      globalPosition,
      View.of(context).viewId,
    );
    for (final entry in result.path) {
      final target = entry.target;
      if (target is! RenderParagraph) continue;
      final localPosition = target.globalToLocal(globalPosition);
      final textPosition = target.getPositionForOffset(localPosition);
      final span = target.text.getSpanForPosition(textPosition);
      final recognizer = span is TextSpan ? span.recognizer : null;
      final onTap = recognizer is TapGestureRecognizer
          ? recognizer.onTap
          : null;
      if (onTap != null) {
        onTap();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (_pointer != null) return;
        _pointer = event.pointer;
        _origin = event.position;
        _tapExpired = false;
        _tapTimer?.cancel();
        _tapTimer = Timer(_maximumLinkTapDuration, () {
          _tapExpired = true;
        });
      },
      onPointerMove: (event) {
        if (event.pointer != _pointer || _origin == null) return;
        if ((event.position - _origin!).distance > kTouchSlop) _moved = true;
      },
      onPointerUp: (event) {
        if (event.pointer != _pointer) return;
        final isTap = !_moved && !_tapExpired;
        _reset();
        if (isTap) _invokeLinkAt(event.position);
      },
      onPointerCancel: (_) => _reset(),
      child: widget.child,
    );
  }
}

const _maximumLinkTapDuration = Duration(milliseconds: 400);

/// 正文图片：保留显式宽高或样式尺寸，稳定占位与 8px 圆角统一裁切。
class _ArticleImageExtension extends TagExtension {
  final List<String> imageUrls;
  final double fontSize;

  _ArticleImageExtension({required this.imageUrls, required this.fontSize})
    : super(tagsToExtend: {'img'}, builder: (ctx) => const SizedBox.shrink());

  @override
  InlineSpan build(ExtensionContext context) {
    final attributes = context.attributes;
    var url =
        attributes['data-actualsrc'] ??
        attributes['data-original'] ??
        attributes['src'];

    // 公式图片优先用 alt 文本渲染 LaTeX。
    final isEquation =
        attributes['class']?.contains('ee_img') == true ||
        (url != null && url.contains('zhihu.com/equation'));
    final isEmoji =
        attributes['data-is-emoji'] == 'true' ||
        attributes['class']?.contains('emoji') == true;
    final altTex = attributes['alt'];

    if (isEquation && altTex != null && altTex.isNotEmpty) {
      String tex = altTex
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll(r'\\', r'\');

      final currentFontSize = context.style?.fontSize?.value ?? fontSize;
      final currentColor = context.style?.color;

      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Math.tex(
          tex,
          textStyle: TextStyle(fontSize: currentFontSize, color: currentColor),
          mathStyle: MathStyle.text,
          onErrorFallback: (err) => Text(tex),
        ),
      );
    }

    if (url == null || url.isEmpty) {
      return const WidgetSpan(child: SizedBox.shrink());
    }

    if (isEmoji) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: CachedNetworkImage(
          imageUrl: url,
          width: 20,
          height: 20,
          httpHeaders: const {'Referer': 'https://www.zhihu.com/'},
          placeholder: (context, url) => const SizedBox(width: 20, height: 20),
          errorWidget: (context, url, error) => Text(altTex ?? ''),
        ),
      );
    }

    if (url.startsWith('//')) {
      url = 'https:$url';
    } else if (!url.startsWith('http')) {
      return const WidgetSpan(child: SizedBox.shrink());
    }

    return WidgetSpan(
      child: _ArticleHtmlImage(
        url: url,
        imageUrls: imageUrls,
        sourceWidth:
            CustomHtml._parseDimension(attributes['width']) ??
            CustomHtml._parseDimension(attributes['data-rawwidth']) ??
            CustomHtml._parseStyleDimension(attributes['style'], 'width'),
        sourceHeight:
            CustomHtml._parseDimension(attributes['height']) ??
            CustomHtml._parseDimension(attributes['data-rawheight']) ??
            CustomHtml._parseStyleDimension(attributes['style'], 'height'),
      ),
    );
  }
}

class _ArticleHtmlImage extends StatefulWidget {
  final String url;
  final List<String> imageUrls;
  final double? sourceWidth;
  final double? sourceHeight;

  const _ArticleHtmlImage({
    required this.url,
    required this.imageUrls,
    this.sourceWidth,
    this.sourceHeight,
  });

  @override
  State<_ArticleHtmlImage> createState() => _ArticleHtmlImageState();
}

class _ArticleHtmlImageState extends State<_ArticleHtmlImage> {
  int _retryCount = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final displayWidth = widget.sourceWidth == null
            ? availableWidth
            : widget.sourceWidth!.clamp(1.0, availableWidth);
        final ratio =
            widget.sourceWidth != null &&
                widget.sourceHeight != null &&
                widget.sourceWidth! > 0 &&
                widget.sourceHeight! > 0
            ? widget.sourceHeight! / widget.sourceWidth!
            : null;
        final maxStableHeight = (displayWidth * 3).clamp(420.0, 1400.0);
        final placeholderHeight = ratio == null
            ? (displayWidth * 0.6).clamp(180.0, 420.0)
            : (displayWidth * ratio).clamp(1.0, maxStableHeight);
        final cacheWidth =
            (displayWidth * MediaQuery.devicePixelRatioOf(context))
                .round()
                .clamp(1, 4096);

        return Align(
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () => ImageViewer.show(
              context,
              widget.url,
              imageUrls: widget.imageUrls,
            ),
            child: Hero(
              tag: widget.url,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  key: ValueKey(_retryCount),
                  imageUrl: widget.url,
                  width: displayWidth,
                  fit: BoxFit.contain,
                  memCacheWidth: cacheWidth,
                  maxWidthDiskCache: cacheWidth * 2,
                  httpHeaders: const {'Referer': 'https://www.zhihu.com/'},
                  fadeInDuration: const Duration(milliseconds: 250),
                  fadeOutDuration: const Duration(milliseconds: 80),
                  placeholder: (context, url) => SizedBox(
                    width: displayWidth,
                    height: placeholderHeight,
                    child: const Center(
                      child: SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => SizedBox(
                    width: displayWidth,
                    height: placeholderHeight,
                    child: ColoredBox(
                      color: colors.surfaceContainerHighest.withValues(
                        alpha: 0.22,
                      ),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () async {
                            await CachedNetworkImage.evictFromCache(widget.url);
                            if (mounted) setState(() => _retryCount++);
                          },
                          icon: Icon(
                            Icons.refresh_rounded,
                            color: colors.onSurfaceVariant,
                          ),
                          label: Text(
                            '重新加载',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 评论“查看图片/动图”缩略图链接：8px 圆角统一裁切，进入现有全屏画廊。
class _CommentImageLinkExtension extends TagExtension {
  final ColorScheme colorScheme;
  final List<String> imageUrls;

  _CommentImageLinkExtension({
    required this.colorScheme,
    required this.imageUrls,
  }) : super(
         tagsToExtend: {'a'},
         builder: (ctx) {
           final href = ctx.attributes['href'] ?? '';
           return _CommentImageThumbnail(url: href, imageUrls: imageUrls);
         },
       );

  @override
  bool matches(ExtensionContext context) {
    if (context.currentStep != CurrentStep.preparing &&
        context.currentStep != CurrentStep.building) {
      return false;
    }
    final href = context.attributes['href'];
    if (href == null || href.isEmpty) return false;
    final text = context.element?.text ?? '';
    if (!(text.contains('查看图片') ||
        text.contains('动图') ||
        text.contains('图片'))) {
      return false;
    }
    return _looksLikeImageUrl(href);
  }

  static bool _looksLikeImageUrl(String href) {
    final lower = href.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        href.contains('zhimg.com');
  }
}

class _CommentImageThumbnail extends StatelessWidget {
  final String url;
  final List<String> imageUrls;

  const _CommentImageThumbnail({required this.url, required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ImageViewer.show(context, url, imageUrls: imageUrls),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: url,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            httpHeaders: const {'Referer': 'https://www.zhihu.com/'},
            fadeInDuration: const Duration(milliseconds: 200),
            fadeOutDuration: const Duration(milliseconds: 100),
            placeholder: (context, url) => Container(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            errorWidget: (context, url, error) => Container(
              width: 120,
              height: 120,
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: const Icon(Icons.broken_image),
            ),
          ),
        ),
      ),
    );
  }
}

/// 引用块：半透明底色、左侧 4px 强调边框与右侧圆角；内部保留链接、行内代码
/// 与文字样式。
class _BlockquoteExtension extends TagExtension {
  final ColorScheme colorScheme;

  _BlockquoteExtension({required this.colorScheme})
    : super(
        tagsToExtend: {'blockquote'},
        builder: (ctx) {
          final spans = ctx.inlineSpanChildren ?? const <InlineSpan>[];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.25),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                border: Border(
                  left: BorderSide(color: colorScheme.primary, width: 4),
                ),
              ),
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  children: spans,
                ),
              ),
            ),
          );
        },
      );

  @override
  bool matches(ExtensionContext context) {
    if (context.currentStep != CurrentStep.preparing &&
        context.currentStep != CurrentStep.building) {
      return false;
    }
    return context.elementName == 'blockquote';
  }
}

/// 整行代码块：全宽容器、8px 圆角、半透明背景与细边框、水平滚动与复制按钮。
///
/// 匹配整个 `<pre>` 元素并用自己的容器替换子树，因此 `<pre><code>` 不会出现
/// 两层代码背景。
class _CodeBlockExtension extends TagExtension {
  _CodeBlockExtension()
    : super(
        tagsToExtend: {'pre'},
        builder: (ctx) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: _CodeBlockWidget(text: ctx.element?.text ?? ''),
        ),
      );

  @override
  bool matches(ExtensionContext context) {
    if (context.currentStep != CurrentStep.preparing &&
        context.currentStep != CurrentStep.building) {
      return false;
    }
    return context.elementName == 'pre';
  }
}

class _CodeBlockWidget extends StatefulWidget {
  final String text;

  const _CodeBlockWidget({required this.text});

  @override
  State<_CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<_CodeBlockWidget> {
  bool _copied = false;

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.text));
    } catch (_) {
      TritiumFeedback.error('复制失败', '无法写入剪贴板');
      return;
    }
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 42, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                widget.text,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontFamilyFallback: const [
                    'Menlo',
                    'Monaco',
                    'Courier New',
                    'Courier',
                  ],
                  fontSize: 13,
                  color: cs.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: InkWell(
              onTap: _copy,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Icon(
                  _copied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 16,
                  color: _copied ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 表格：宽表可横向滚动，首行表头底色与整表边框。
class _ArticleTableExtension extends TagExtension {
  _ArticleTableExtension()
    : super(
        tagsToExtend: {'table'},
        builder: (ctx) => _ArticleTableWidget(
          table: ctx.element,
          textDirection: ctx.buildContext != null
              ? Directionality.maybeOf(ctx.buildContext!)
              : null,
        ),
      );

  @override
  bool matches(ExtensionContext context) {
    if (context.currentStep != CurrentStep.preparing &&
        context.currentStep != CurrentStep.building) {
      return false;
    }
    return context.elementName == 'table';
  }
}

class _ArticleTableWidget extends StatelessWidget {
  final dom.Element? table;
  final TextDirection? textDirection;

  const _ArticleTableWidget({required this.table, this.textDirection});

  @override
  Widget build(BuildContext context) {
    final rows = _parseTableRows(table);
    if (rows.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    final columnCount = rows.fold<int>(
      0,
      (maxCount, row) => row.length > maxCount ? row.length : maxCount,
    );
    if (columnCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final columnWidth = math.max(
            112.0,
            math.min(180.0, maxWidth / math.min(columnCount, 4)),
          );
          final tableWidth = columnWidth * columnCount;
          final textDirection =
              this.textDirection ?? Directionality.maybeOf(context);

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: maxWidth,
                maxWidth: tableWidth > maxWidth ? tableWidth : maxWidth,
              ),
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder.all(color: cs.outlineVariant, width: 0.8),
                columnWidths: {
                  for (var i = 0; i < columnCount; i++)
                    i: FixedColumnWidth(columnWidth),
                },
                children: [
                  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
                    TableRow(
                      decoration: BoxDecoration(
                        color: rowIndex == 0
                            ? cs.surfaceContainerHighest.withValues(alpha: 0.55)
                            : Colors.transparent,
                      ),
                      children: [
                        for (
                          var cellIndex = 0;
                          cellIndex < columnCount;
                          cellIndex++
                        )
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Text(
                              cellIndex < rows[rowIndex].length
                                  ? rows[rowIndex][cellIndex]
                                  : '',
                              textDirection: textDirection,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: cs.onSurface,
                                fontWeight: (rowIndex == 0)
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static List<List<String>> _parseTableRows(dom.Element? table) {
    if (table == null) return const [];
    final rows = <List<String>>[];
    for (final tr in table.querySelectorAll('tr')) {
      final cells = <String>[];
      for (final child in tr.children) {
        final tag = child.localName?.toLowerCase();
        if (tag != 'td' && tag != 'th') continue;
        final text = child.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        final colSpan = int.tryParse(child.attributes['colspan'] ?? '') ?? 1;
        cells.add(text);
        for (var i = 1; i < colSpan.clamp(1, 12); i++) {
          cells.add('');
        }
      }
      if (cells.any((cell) => cell.isNotEmpty)) {
        rows.add(cells);
      }
    }
    return rows;
  }
}

/// 行内代码扩展 — 使用 alphabetic baseline 对齐的半透明圆角胶囊，
/// 避免背景叠加或上下错位；`<pre>` 内的 `<code>` 不匹配，防止双层背景。
class InlineCodeExtension extends HtmlExtension {
  final ColorScheme colorScheme;

  const InlineCodeExtension({required this.colorScheme});

  @override
  Set<String> get supportedTags => {'code'};

  @override
  bool matches(ExtensionContext context) {
    switch (context.currentStep) {
      case CurrentStep.preparing:
        // 只匹配 <code> 元素，且排除 <pre> 内的整行代码块。
        if (context.elementName != 'code') return false;
        var node = context.element?.parent;
        while (node != null) {
          if (node.localName?.toLowerCase() == 'pre') return false;
          node = node.parent;
        }
        return true;
      case CurrentStep.building:
        return context.styledElement is _InlineCodeWrapperElement;
      case CurrentStep.preStyling:
      case CurrentStep.preProcessing:
        return false;
    }
  }

  @override
  StyledElement prepare(
    ExtensionContext context,
    List<StyledElement> children,
  ) {
    return _InlineCodeWrapperElement(
      child: context.parser.prepareFromExtension(
        context,
        children,
        extensionsToIgnore: {this},
      ),
    );
  }

  @override
  InlineSpan build(ExtensionContext context) {
    final child = CssBoxWidget.withInlineSpanChildren(
      children: context.inlineSpanChildren!,
      style: context.style!,
    );

    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: child,
      ),
    );
  }
}

class _InlineCodeWrapperElement extends StyledElement {
  _InlineCodeWrapperElement({required StyledElement child})
    : super(
        node: dom.Element.tag("inline-code-wrapper"),
        style: Style(),
        children: [child],
        name: "[inline-code-wrapper]",
      );
}
