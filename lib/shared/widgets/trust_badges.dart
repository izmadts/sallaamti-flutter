import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

// The three verification signals (CNIC / payment / guardian) a Nikah
// profile can carry — rendered as bold filled pills, not generic grey
// chips, so trust reads the same way everywhere it's shown: on the Browse
// grid and on a profile's own detail page.
class TrustBadges extends StatelessWidget {
  final Map<String, bool> trustBadges;
  final bool small;
  final Axis direction;

  const TrustBadges({
    super.key,
    required this.trustBadges,
    this.small = false,
    this.direction = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 'payment' deliberately isn't a badge of its own — the 'cnic' key here
    // is a legacy name, but the signal it carries is verification_status
    // (admin-confirmed payment), not actual CNIC presence, which is optional.
    // It keeps the single "Trusted" label rather than stacking a second pill.
    final labelsAndColors = {
      'cnic': (l10n.trustBadgeTrusted, const Color(0xFF10B981)),
      'guardian': (l10n.trustBadgeGuardianVerified, Colors.purple.shade500),
    };
    final active = labelsAndColors.entries.where((e) => trustBadges[e.key] == true).map((e) => e.value).toList();
    final pills = active.isEmpty
        ? [(l10n.trustBadgePending, Colors.grey.shade600)]
        : active;

    final children = pills.map((p) => _pill(p.$1, p.$2)).toList();

    return direction == Axis.horizontal
        ? Wrap(spacing: 8, runSpacing: 8, children: children)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 3), child: c)).toList(),
          );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 10, vertical: small ? 2 : 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: Colors.white, fontSize: small ? 10 : 12, fontWeight: FontWeight.w700)),
    );
  }
}
