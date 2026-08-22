import 'package:flutter/material.dart';

// A field label with a red asterisk for required fields — optional fields
// get no suffix at all (no "(optional)" text) rather than mark every field
// one way or the other.
Widget requiredLabel(String text) {
  return Text.rich(
    TextSpan(
      children: [
        TextSpan(text: text),
        const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
      ],
    ),
  );
}
