import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Matches paragraph content without treating layout separators as content.
Finder renderedText(String text) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText().trim() == text,
);

/// Targets the actual glyphs, excluding paragraph width and trailing blank lines.
Rect renderedTextRect(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(renderedText(text));
  final start = paragraph.text.toPlainText().indexOf(text);
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: start + text.length),
  );
  if (boxes.isEmpty) throw StateError('No rendered glyphs for $text');
  final local = boxes.first.toRect();
  return local.shift(paragraph.localToGlobal(Offset.zero));
}
