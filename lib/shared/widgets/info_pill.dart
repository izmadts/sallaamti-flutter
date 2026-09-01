import 'package:flutter/material.dart';

// A small rounded label — course category, age range, gender restriction —
// used across course/class catalog and detail screens so those badges look
// and behave identically wherever a module needs one, instead of each
// screen hand-rolling its own Container/BoxDecoration.
class InfoPill extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;

  const InfoPill({super.key, required this.text, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: filled ? Colors.white : color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
