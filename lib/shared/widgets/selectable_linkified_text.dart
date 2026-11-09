import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// A Wall post/dua's body is member-typed plain text, not admin-authored
// Trix HTML (unlike html_text.dart's content), so there's never an <a> tag
// to begin with — a bare "https://…" or "www.…" the member typed needs to
// be found and made tappable by pattern alone. Also selectable (plain Text
// isn't), so a member can actually copy a verse reference, a phone number,
// etc. out of a post.
final _urlPattern = RegExp(
  r'((https?:\/\/|www\.)[^\s]+)',
  caseSensitive: false,
);

class SelectableLinkifiedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const SelectableLinkifiedText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final linkColor = Theme.of(context).colorScheme.primary;

    final spans = <TextSpan>[];
    var index = 0;

    for (final match in _urlPattern.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }

      final raw = match.group(0)!;
      final url = raw.startsWith('www.') ? 'https://$raw' : raw;

      spans.add(TextSpan(
        text: raw,
        style: effectiveStyle.copyWith(color: linkColor, decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.tryParse(url);
            if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
      ));

      index = match.end;
    }

    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }

    return SelectableText.rich(TextSpan(style: effectiveStyle, children: spans));
  }
}
