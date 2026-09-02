import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

// Single source of truth for a module's emoji/label/route, shared by the
// dashboard grid, the bottom nav's "recent module" tab, and the More sheet's
// module list — previously duplicated inline in dashboard_screen.dart.
const moduleEmoji = {
  'nikah': '💍',
  'quran': '📖',
  'quran_live': '🕌',
  'skills': '💻',
  'counseling': '🤝',
  'donation': '💝',
  'volunteer': '🙌',
  'wall': '📣',
  'community': '📰',
};

String moduleLabel(BuildContext context, String module) {
  final l10n = AppLocalizations.of(context)!;
  return switch (module) {
    'nikah' => l10n.moduleNikah,
    'quran' => l10n.moduleQuran,
    'quran_live' => l10n.moduleQuranLive,
    'skills' => l10n.moduleSkills,
    'counseling' => l10n.moduleCounseling,
    'donation' => l10n.moduleDonation,
    'volunteer' => l10n.moduleVolunteer,
    'wall' => l10n.moduleWall,
    'community' => l10n.moduleCommunity,
    _ => module,
  };
}

// Where tapping this module actually goes — mirrors dashboard_screen.dart's
// _ModuleTile.onTap switch exactly, so every entry point (dashboard grid,
// bottom nav, More sheet) lands in the same place.
String? moduleRoute(String module) => switch (module) {
      'nikah' => '/nikah',
      'volunteer' => '/volunteer',
      'donation' => '/donate',
      'wall' => '/wall',
      'counseling' => '/counseling',
      'quran' => '/quran-hub',
      'skills' => '/learning/track/skills',
      'community' => '/community',
      _ => null,
    };

// Which module a given route path belongs to, for "recently opened module"
// tracking — the inverse of moduleRoute(), matched by prefix since a
// module's sub-screens (e.g. /nikah/browse) should still count.
const _pathPrefixToModule = {
  '/nikah': 'nikah',
  '/quran-hub': 'quran',
  '/quran-live': 'quran',
  '/learning': 'skills',
  '/counseling': 'counseling',
  '/donate': 'donation',
  '/volunteer': 'volunteer',
  '/community': 'community',
};

String? moduleForPath(String path) {
  for (final entry in _pathPrefixToModule.entries) {
    if (path == entry.key || path.startsWith('${entry.key}/')) {
      return entry.value;
    }
  }
  return null;
}
