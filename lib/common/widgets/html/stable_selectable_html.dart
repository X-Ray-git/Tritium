import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

/// Keeps flutter_html's parser and render paragraphs alive while the rendered
/// document is unchanged, so unrelated parent rebuilds do not clear an active
/// system text selection.
class StableSelectableHtml extends StatefulWidget {
  const StableSelectableHtml({
    super.key,
    required this.data,
    this.style = const {},
    this.onLinkTap,
    this.onAnchorTap,
    this.extensions = const [],
    this.renderConfigurationKey,
  });

  final String data;
  final Map<String, Style> style;
  final OnTap? onLinkTap;
  final OnTap? onAnchorTap;
  final List<HtmlExtension> extensions;
  final Object? renderConfigurationKey;

  @override
  State<StableSelectableHtml> createState() => _StableSelectableHtmlState();
}

class _StableSelectableHtmlState extends State<StableSelectableHtml> {
  GlobalKey _anchorKey = GlobalKey();

  @override
  void didUpdateWidget(covariant StableSelectableHtml oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.renderConfigurationKey != widget.renderConfigurationKey) {
      _anchorKey = GlobalKey();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Html(
      anchorKey: _anchorKey,
      data: widget.data,
      style: widget.style,
      onLinkTap: widget.onLinkTap,
      onAnchorTap: widget.onAnchorTap,
      extensions: widget.extensions,
    );
  }
}
