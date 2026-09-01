import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sallaamti_app/shared/widgets/html_text.dart';

// HtmlText parses lesson/blog/post bodies by hand rather than through an
// HTML package, so these pin down the subset it has to get right — the markup
// Trix actually produces in the admin editor.

/// Every string HtmlText rendered, block by block, in order.
List<String> _renderedText(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
      .where((s) => s.isNotEmpty)
      .toList();
}

Future<void> _pump(WidgetTester tester, String html) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: HtmlText(html: html)))),
  );
}

void main() {
  testWidgets('renders plain text with no markup', (tester) async {
    await _pump(tester, 'lesson 1 test class');

    expect(_renderedText(tester), ['lesson 1 test class']);
  });

  testWidgets('splits Trix div blocks into separate paragraphs', (tester) async {
    await _pump(tester, '<div>First para</div><div>Second para</div>');

    expect(_renderedText(tester), ['First para', 'Second para']);
  });

  testWidgets('keeps inline styles as one block, not split per tag', (tester) async {
    await _pump(tester, '<div>A <strong>bold</strong> and <em>italic</em> line</div>');

    expect(_renderedText(tester), ['A bold and italic line']);
  });

  testWidgets('numbers ordered list items and leaves bullets unnumbered', (tester) async {
    await _pump(tester, '<ol><li>One</li><li>Two</li><li>Three</li></ol>');

    // Each item renders its own marker Text plus its content Text.
    expect(_renderedText(tester), ['1.', 'One', '2.', 'Two', '3.', 'Three']);

    await _pump(tester, '<ul><li>Alpha</li><li>Beta</li></ul>');

    expect(_renderedText(tester), ['•', 'Alpha', '•', 'Beta']);
  });

  testWidgets('restarts numbering for a second ordered list', (tester) async {
    await _pump(tester, '<ol><li>One</li></ol><ol><li>One again</li></ol>');

    expect(_renderedText(tester), ['1.', 'One', '1.', 'One again']);
  });

  testWidgets('renders headings, quotes and code as their own blocks', (tester) async {
    await _pump(tester, '<h1>Title</h1><blockquote>A quote</blockquote><pre>code()</pre>');

    expect(_renderedText(tester), ['Title', 'A quote', 'code()']);
  });

  testWidgets('turns <br> into a line break inside one block', (tester) async {
    await _pump(tester, '<div>Line one<br>Line two</div>');

    expect(_renderedText(tester), ['Line one\nLine two']);
  });

  testWidgets('decodes HTML entities', (tester) async {
    await _pump(tester, '<div>Tea &amp; dates &lt;3 &quot;really&quot; &#39;good&#39;</div>');

    expect(_renderedText(tester), ['Tea & dates <3 "really" \'good\'']);
  });

  testWidgets('drops whitespace-only blocks rather than padding with blanks', (tester) async {
    await _pump(tester, '<div>Real content</div>\n  \n<div>  </div>\n<div>More</div>');

    expect(_renderedText(tester), ['Real content', 'More']);
  });

  testWidgets('degrades an unsupported tag to its text instead of showing markup', (tester) async {
    await _pump(tester, '<div>Before<table><tr><td>Cell</td></tr></table>After</div>');

    expect(_renderedText(tester).join(' '), contains('Cell'));
    expect(_renderedText(tester).join(' '), isNot(contains('<')));
  });

  testWidgets('renders nothing for empty or tag-only input', (tester) async {
    await _pump(tester, '<div></div>');

    expect(_renderedText(tester), isEmpty);
  });

  testWidgets('keeps link text and exposes the href to onLinkTap', (tester) async {
    String? tapped;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HtmlText(
            html: '<div>Read <a href="https://sallaamti.com/guide">the guide</a> first</div>',
            onLinkTap: (url) => tapped = url,
          ),
        ),
      ),
    );

    expect(_renderedText(tester), ['Read the guide first']);

    // The recognizer is attached to the link span only; firing it directly is
    // enough to prove the href survived parsing.
    final span = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
    final linkSpan = span.children!.cast<TextSpan>().firstWhere((s) => s.recognizer != null);
    (linkSpan.recognizer as TapGestureRecognizer).onTap!();

    expect(tapped, 'https://sallaamti.com/guide');
  });
}
