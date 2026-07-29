import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'custom_html.dart';

/// Compact, non-interactive HTML preview used by inline child comments.
///
/// Text formatting and Zhihu emoji are retained, while regular content images
/// and link interactions are intentionally omitted so the whole preview keeps
/// its "open replies" action.
class CompactHtmlPreview extends StatelessWidget {
  final String content;
  final String prefix;
  final TextStyle prefixStyle;
  final TextStyle textStyle;
  final int maxLines;

  const CompactHtmlPreview({
    super.key,
    required this.content,
    required this.prefix,
    required this.prefixStyle,
    required this.textStyle,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[TextSpan(text: prefix, style: prefixStyle)];
    final fragment = html_parser.parseFragment(content);
    for (final node in fragment.nodes) {
      _appendNode(node, spans, textStyle);
    }
    _trimTrailingWhitespace(spans);

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  static void _appendNode(
    dom.Node node,
    List<InlineSpan> spans,
    TextStyle style,
  ) {
    if (node is dom.Text) {
      _appendText(node.data, spans, style);
      return;
    }
    if (node is! dom.Element) return;

    final tag = node.localName?.toLowerCase();
    if (tag == 'br') {
      spans.add(TextSpan(text: '\n', style: style));
      return;
    }
    if (tag == 'img') {
      final emoji = _emojiFromElement(node);
      if (emoji != null) spans.add(_emojiSpan(emoji, style));
      return;
    }

    var childStyle = style;
    if (tag == 'strong' || tag == 'b') {
      childStyle = style.copyWith(fontWeight: FontWeight.w700);
    } else if (tag == 'em' || tag == 'i') {
      childStyle = style.copyWith(fontStyle: FontStyle.italic);
    }
    for (final child in node.nodes) {
      _appendNode(child, spans, childStyle);
    }
    if (_blockTags.contains(tag)) {
      spans.add(TextSpan(text: '\n', style: style));
    }
  }

  static void _appendText(
    String text,
    List<InlineSpan> spans,
    TextStyle style,
  ) {
    var cursor = 0;
    for (final match in _emojiPattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: text.substring(cursor, match.start), style: style),
        );
      }
      final name = match.group(1)!;
      final url = CustomHtml.emojiUrl(name);
      if (url == null) {
        spans.add(TextSpan(text: match.group(0), style: style));
      } else {
        spans.add(
          _emojiSpan(_PreviewEmoji(url: url, fallback: match.group(0)!), style),
        );
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: style));
    }
  }

  static _PreviewEmoji? _emojiFromElement(dom.Element element) {
    final alt = element.attributes['alt'] ?? '';
    final nameMatch = _wholeEmojiPattern.firstMatch(alt.trim());
    final mappedUrl = nameMatch == null
        ? null
        : CustomHtml.emojiUrl(nameMatch.group(1)!);
    final isEmoji =
        element.classes.contains('emoji') ||
        element.attributes['data-is-emoji'] == 'true' ||
        mappedUrl != null;
    if (!isEmoji) return null;

    var url =
        mappedUrl ??
        element.attributes['data-actualsrc'] ??
        element.attributes['data-original'] ??
        element.attributes['src'];
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('//')) url = 'https:$url';
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;
    return _PreviewEmoji(url: url, fallback: alt);
  }

  static InlineSpan _emojiSpan(_PreviewEmoji emoji, TextStyle style) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: CachedNetworkImage(
        imageUrl: emoji.url,
        width: 20,
        height: 20,
        fit: BoxFit.contain,
        httpHeaders: const {'Referer': 'https://www.zhihu.com/'},
        placeholder: (context, url) => const SizedBox.square(dimension: 20),
        errorWidget: (context, url, error) =>
            Text(emoji.fallback, style: style),
      ),
    );
  }

  static void _trimTrailingWhitespace(List<InlineSpan> spans) {
    while (spans.isNotEmpty) {
      final last = spans.last;
      if (last is! TextSpan || last.children != null) return;
      final text = last.text ?? '';
      final trimmed = text.trimRight();
      if (trimmed.isEmpty) {
        spans.removeLast();
        continue;
      }
      if (trimmed != text) {
        spans[spans.length - 1] = TextSpan(text: trimmed, style: last.style);
      }
      return;
    }
  }

  static final _emojiPattern = RegExp(r'\[([^\s\[\]]{1,10})\]');
  static final _wholeEmojiPattern = RegExp(r'^\[([^\s\[\]]{1,10})\]$');
  static const _blockTags = {'blockquote', 'div', 'li', 'ol', 'p', 'pre', 'ul'};
}

class _PreviewEmoji {
  final String url;
  final String fallback;

  const _PreviewEmoji({required this.url, required this.fallback});
}
