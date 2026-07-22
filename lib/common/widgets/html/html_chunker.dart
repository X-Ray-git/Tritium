import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// 将长 HTML 拆成可惰性构建的语义块。
///
/// Tritium 只按块级边界拆分，不改写知乎的行内标记、公式或图片属性；这些内容仍由
/// [CustomHtml] 统一渲染。
abstract final class HtmlChunker {
  static const minChunkingLength = 12 * 1024;
  static const targetChunkLength = 2400;
  static const _maxCachedDocuments = 6;
  static final LinkedHashMap<String, Future<List<String>>> _parseCache =
      LinkedHashMap();

  static const _transparentContainers = {
    'article',
    'body',
    'div',
    'main',
    'section',
  };

  static const _discardedTags = {'link', 'meta', 'script', 'style'};

  static Future<List<String>> parse(String source) {
    final cached = _parseCache.remove(source);
    if (cached != null) {
      _parseCache[source] = cached;
      return cached;
    }

    final parsing = Isolate.run(() => parseSync(source));
    _parseCache[source] = parsing;
    while (_parseCache.length > _maxCachedDocuments) {
      _parseCache.remove(_parseCache.keys.first);
    }
    unawaited(
      parsing.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {
          if (identical(_parseCache[source], parsing)) {
            _parseCache.remove(source);
          }
        },
      ),
    );
    return parsing;
  }

  static void preload(String source) {
    if (source.length >= minChunkingLength) unawaited(parse(source));
  }

  static List<String> parseSync(String source) {
    if (source.trim().isEmpty) return const [];
    final fragment = html_parser.parseFragment(source);
    for (final element in fragment.querySelectorAll('script,style,link,meta')) {
      element.remove();
    }
    final blocks = <String>[];
    _collect(fragment.nodes, blocks);
    return _groupSmallBlocks(blocks);
  }

  static List<String> extractImageUrls(String source) {
    if (source.trim().isEmpty) return const [];
    final urls = <String>[];
    final seen = <String>{};
    final imageTags = RegExp(
      r'<img\b[^>]*>',
      caseSensitive: false,
    ).allMatches(source);
    for (final match in imageTags) {
      final tag = match.group(0)!;
      String? attribute(String name) => RegExp(
        '$name\\s*=\\s*["\']([^"\']*)["\']',
        caseSensitive: false,
      ).firstMatch(tag)?.group(1);

      final classes = attribute('class') ?? '';
      if (classes.contains('emoji') ||
          classes.contains('ee_img') ||
          attribute('data-is-emoji') == 'true') {
        continue;
      }
      var url =
          attribute('data-actualsrc') ??
          attribute('data-original') ??
          attribute('src');
      if (url == null || url.isEmpty || url.contains('zhihu.com/equation')) {
        continue;
      }
      if (url.startsWith('//')) url = 'https:$url';
      if (!url.startsWith('http://') && !url.startsWith('https://')) continue;
      if (seen.add(url)) urls.add(url);
    }
    return List.unmodifiable(urls);
  }

  static void _collect(Iterable<dom.Node> nodes, List<String> blocks) {
    final textBuffer = StringBuffer();

    void flushText() {
      final text = textBuffer.toString().trim();
      textBuffer.clear();
      if (text.isNotEmpty) blocks.add('<p>$text</p>');
    }

    for (final node in nodes) {
      if (node is dom.Text) {
        if (node.text.trim().isNotEmpty) {
          textBuffer.write(const HtmlEscape().convert(node.text));
        }
        continue;
      }
      if (node is! dom.Element) continue;

      final tag = node.localName?.toLowerCase() ?? '';
      if (_discardedTags.contains(tag)) continue;
      flushText();

      if (_transparentContainers.contains(tag) &&
          node.children.isNotEmpty &&
          _hasBlockChildren(node)) {
        _collect(node.nodes, blocks);
      } else {
        final html = node.outerHtml.trim();
        if (html.isNotEmpty) blocks.add(html);
      }
    }
    flushText();
  }

  static bool _hasBlockChildren(dom.Element element) {
    const blockTags = {
      'article',
      'blockquote',
      'div',
      'figure',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'hr',
      'ol',
      'p',
      'pre',
      'section',
      'table',
      'ul',
    };
    return element.children.any(
      (child) => blockTags.contains(child.localName?.toLowerCase()),
    );
  }

  static List<String> _groupSmallBlocks(List<String> blocks) {
    if (blocks.length <= 1) return List.unmodifiable(blocks);
    final chunks = <String>[];
    var buffer = StringBuffer();

    void flush() {
      if (buffer.isEmpty) return;
      chunks.add(buffer.toString());
      buffer = StringBuffer();
    }

    for (final block in blocks) {
      final containsStableMedia = RegExp(
        r'<(?:img|figure|pre|table|video|iframe)\b',
        caseSensitive: false,
      ).hasMatch(block);
      if (containsStableMedia) {
        flush();
        chunks.add(block);
        continue;
      }
      if (buffer.isNotEmpty &&
          buffer.length + block.length > targetChunkLength) {
        flush();
      }
      buffer.write(block);
    }
    flush();
    return List.unmodifiable(chunks);
  }
}
