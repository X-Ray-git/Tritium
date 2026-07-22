import 'package:flutter_test/flutter_test.dart';
import 'package:tritium/common/widgets/html/html_chunker.dart';

void main() {
  test('keeps inline markup and separates stable media blocks', () {
    final chunks = HtmlChunker.parseSync('''
      <div>
        <p>第一段 <strong>重点</strong></p>
        <figure><img src="https://example.com/a.png" width="320"></figure>
        <p>最后一段</p>
      </div>
    ''');

    expect(chunks, hasLength(3));
    expect(chunks[0], contains('<strong>重点</strong>'));
    expect(chunks[1], contains('<img'));
    expect(chunks[2], contains('最后一段'));
  });

  test('drops executable and document-style nodes', () {
    final chunks = HtmlChunker.parseSync('''
      <style>p { color: red; }</style>
      <script>alert('x')</script>
      <p>可见正文<script>alert('nested')</script></p>
    ''');

    final result = chunks.join();
    expect(result, contains('可见正文'));
    expect(result, isNot(contains('<script')));
    expect(result, isNot(contains('<style')));
  });

  test('extracts gallery images and excludes emoji and equations', () {
    final urls = HtmlChunker.extractImageUrls('''
      <img data-original="//pic.example.com/a.jpg" width="640">
      <img src="https://pic.example.com/b.webp">
      <img class="emoji" src="https://pic.example.com/emoji.png">
      <img class="ee_img" src="https://www.zhihu.com/equation/1">
      <img src="https://pic.example.com/b.webp">
    ''');

    expect(urls, [
      'https://pic.example.com/a.jpg',
      'https://pic.example.com/b.webp',
    ]);
  });
}
