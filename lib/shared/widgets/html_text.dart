import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// Renders the HTML that lesson content is authored in. The admin panel uses
// Trix, so the markup is a small, known subset — headings, paragraphs, bold/
// italic/underline/strike, links, ordered and unordered lists, blockquotes,
// code and images. That's narrow enough to render with a tokenizer here
// rather than taking on an HTML-rendering dependency, which also keeps the
// typography under the app's own control instead of a package's defaults.
//
// Anything outside that subset degrades to its text content rather than
// showing raw tags to the member.
class HtmlText extends StatelessWidget {
  final String html;
  final TextStyle? baseStyle;
  final void Function(String url)? onLinkTap;

  const HtmlText({super.key, required this.html, this.baseStyle, this.onLinkTap});

  @override
  Widget build(BuildContext context) {
    final style = baseStyle ??
        TextStyle(fontSize: 15, height: 1.55, color: Colors.grey.shade800);
    final blocks = _HtmlParser(html).parse();

    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == blocks.length - 1 ? 0 : 10),
            child: _buildBlock(context, blocks[i], style),
          ),
      ],
    );
  }

  Widget _buildBlock(BuildContext context, _Block block, TextStyle style) {
    final color = Theme.of(context).colorScheme.primary;

    switch (block.type) {
      case _BlockType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            block.imageUrl!,
            fit: BoxFit.cover,
            // A broken image in lesson content shouldn't blow up the whole
            // lesson screen — just leave a quiet placeholder.
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        );

      case _BlockType.heading:
        return Text(
          block.plainText,
          style: style.copyWith(
            fontSize: switch (block.headingLevel) { 1 => 22, 2 => 19, 3 => 17, _ => 16 },
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade900,
            height: 1.3,
          ),
        );

      case _BlockType.quote:
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: _richText(block, style.copyWith(fontStyle: FontStyle.italic), color),
        );

      case _BlockType.code:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            block.plainText,
            style: style.copyWith(fontFamily: 'monospace', fontSize: 13.5),
          ),
        );

      case _BlockType.listItem:
        return Padding(
          padding: EdgeInsets.only(left: 4.0 + (block.listDepth * 16)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  block.listNumber != null ? '${block.listNumber}.' : '•',
                  style: style.copyWith(fontWeight: FontWeight.w700, color: color),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _richText(block, style, color)),
            ],
          ),
        );

      case _BlockType.paragraph:
        return _richText(block, style, color);
    }
  }

  Widget _richText(_Block block, TextStyle style, Color linkColor) {
    return Text.rich(
      TextSpan(
        children: block.spans.map((span) {
          final effective = style.merge(span.style);

          return TextSpan(
            text: span.text,
            style: span.href != null
                ? effective.copyWith(color: linkColor, decoration: TextDecoration.underline)
                : effective,
            recognizer: span.href != null && onLinkTap != null
                ? (TapGestureRecognizer()..onTap = () => onLinkTap!(span.href!))
                : null,
          );
        }).toList(),
      ),
    );
  }
}

enum _BlockType { paragraph, heading, listItem, quote, code, image }

class _Span {
  final String text;
  final TextStyle? style;
  final String? href;
  _Span(this.text, {this.style, this.href});
}

class _Block {
  final _BlockType type;
  final List<_Span> spans;
  final int headingLevel;
  final int? listNumber;
  final int listDepth;
  final String? imageUrl;

  _Block({
    required this.type,
    this.spans = const [],
    this.headingLevel = 1,
    this.listNumber,
    this.listDepth = 0,
    this.imageUrl,
  });

  String get plainText => spans.map((s) => s.text).join();

  bool get isEmpty => type != _BlockType.image && plainText.trim().isEmpty;
}

// A single left-to-right pass over the markup, keeping a stack of the inline
// styles currently open and a stack of the list types currently open, so
// nesting (a bold link inside a list item inside a list) comes out right.
class _HtmlParser {
  static final _tagPattern = RegExp(r'<(/?)\s*([a-zA-Z0-9]+)((?:"[^"]*"|' "'[^']*'" r'|[^>])*?)/?>');
  static final _hrefPattern = RegExp(r'''href\s*=\s*["']([^"']*)["']''', caseSensitive: false);
  static final _srcPattern = RegExp(r'''src\s*=\s*["']([^"']*)["']''', caseSensitive: false);

  final String _html;
  _HtmlParser(this._html);

  final List<_Block> _blocks = [];
  final List<_Span> _current = [];
  final List<TextStyle> _styleStack = [];
  final List<String?> _hrefStack = [];
  // Each entry is an open <ul>/<ol>; the value counts items seen so far so
  // ordered lists number correctly, including when they're nested.
  final List<_ListContext> _lists = [];

  _BlockType _blockType = _BlockType.paragraph;
  int _headingLevel = 1;

  List<_Block> parse() {
    var index = 0;

    for (final match in _tagPattern.allMatches(_html)) {
      if (match.start > index) {
        _appendText(_html.substring(index, match.start));
      }
      index = match.end;

      final isClosing = match.group(1) == '/';
      final tag = match.group(2)!.toLowerCase();
      final attrs = match.group(3) ?? '';

      if (isClosing) {
        _closeTag(tag);
      } else {
        _openTag(tag, attrs);
      }
    }

    if (index < _html.length) {
      _appendText(_html.substring(index));
    }

    _flush();
    return _blocks;
  }

  void _openTag(String tag, String attrs) {
    switch (tag) {
      case 'br':
        _current.add(_Span('\n'));
      case 'strong':
      case 'b':
        _pushStyle(const TextStyle(fontWeight: FontWeight.w700));
      case 'em':
      case 'i':
        _pushStyle(const TextStyle(fontStyle: FontStyle.italic));
      case 'u':
        _pushStyle(const TextStyle(decoration: TextDecoration.underline));
      case 'del':
      case 's':
      case 'strike':
        _pushStyle(const TextStyle(decoration: TextDecoration.lineThrough));
      case 'code':
        _pushStyle(const TextStyle(fontFamily: 'monospace'));
      case 'a':
        _hrefStack.add(_hrefPattern.firstMatch(attrs)?.group(1));
      case 'img':
        final src = _srcPattern.firstMatch(attrs)?.group(1);
        if (src != null && src.isNotEmpty) {
          _flush();
          _blocks.add(_Block(type: _BlockType.image, imageUrl: src));
        }
      case 'ul':
        _lists.add(_ListContext(ordered: false));
      case 'ol':
        _lists.add(_ListContext(ordered: true));
      case 'li':
        _flush();
        _blockType = _BlockType.listItem;
      case 'blockquote':
        _flush();
        _blockType = _BlockType.quote;
      case 'pre':
        _flush();
        _blockType = _BlockType.code;
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        _flush();
        _blockType = _BlockType.heading;
        _headingLevel = int.parse(tag.substring(1));
      case 'p':
      case 'div':
        _flush();
    }
  }

  void _closeTag(String tag) {
    switch (tag) {
      case 'strong':
      case 'b':
      case 'em':
      case 'i':
      case 'u':
      case 'del':
      case 's':
      case 'strike':
      case 'code':
        if (_styleStack.isNotEmpty) _styleStack.removeLast();
      case 'a':
        if (_hrefStack.isNotEmpty) _hrefStack.removeLast();
      case 'ul':
      case 'ol':
        if (_lists.isNotEmpty) _lists.removeLast();
      case 'li':
      case 'blockquote':
      case 'pre':
      case 'p':
      case 'div':
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        _flush();
    }
  }

  void _pushStyle(TextStyle style) {
    _styleStack.add(_styleStack.isEmpty ? style : _styleStack.last.merge(style));
  }

  void _appendText(String raw) {
    final text = _decodeEntities(raw);
    if (text.isEmpty) return;

    _current.add(_Span(
      text,
      style: _styleStack.isEmpty ? null : _styleStack.last,
      href: _hrefStack.isEmpty ? null : _hrefStack.last,
    ));
  }

  void _flush() {
    if (_current.isNotEmpty) {
      final listContext = _lists.isEmpty ? null : _lists.last;

      final block = _Block(
        type: _blockType,
        spans: List.of(_current),
        headingLevel: _headingLevel,
        listNumber: _blockType == _BlockType.listItem && (listContext?.ordered ?? false)
            ? ++listContext!.count
            : null,
        listDepth: _blockType == _BlockType.listItem ? (_lists.length - 1).clamp(0, 4) : 0,
      );

      // Whitespace between tags produces empty blocks; dropping them here
      // stops the lesson body being padded out with blank lines.
      if (!block.isEmpty) {
        _blocks.add(block);
      }
      _current.clear();
    }

    _blockType = _BlockType.paragraph;
    _headingLevel = 1;
  }

  static String _decodeEntities(String input) {
    if (!input.contains('&')) return input;

    return input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAllMapped(
          RegExp(r'&#(\d+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!)),
        );
  }
}

class _ListContext {
  final bool ordered;
  int count = 0;
  _ListContext({required this.ordered});
}
