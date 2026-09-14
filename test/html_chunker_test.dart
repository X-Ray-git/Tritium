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

  test('drops formatting-only chunks that are unsafe for selection', () {
    final chunks = HtmlChunker.parseSync('''
      <p><br></p>
      <p><span></span></p>
      <p><a href="https://example.com"></a></p>
      <blockquote><br></blockquote>
      <ul><li><span></span></li></ul>
      <table><tbody><tr><td><br></td></tr></tbody></table>
      <source type="image/webp" srcset="https://example.com/image.webp">
      <input disabled type="checkbox">
      <button><svg></svg></button>
    ''');

    expect(chunks, isEmpty);
  });

  test('keeps meaningful text and widget-only content', () {
    final chunks = HtmlChunker.parseSync('''
      <p>Hello <code>world</code></p>
      <blockquote><img src="https://example.com/image.webp"></blockquote>
      <hr>
    ''');

    expect(chunks.join(), contains('Hello'));
    expect(chunks.join(), contains('<img'));
    expect(chunks.join(), contains('<hr'));
  });
}
