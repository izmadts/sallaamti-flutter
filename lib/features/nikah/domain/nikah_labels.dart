import '../../../l10n/generated/app_localizations.dart';

// Several raw enum values from the backend (marital_status, matchmaker
// tier) used to just be shown with underscores swapped for spaces (e.g.
// "never married", "certified nikah counselor") — never actually
// translated, in either language. Centralized here since multiple Nikah
// screens display the same values.
String maritalStatusLabel(AppLocalizations l10n, String? value) => {
      'never_married': l10n.maritalStatusNeverMarried,
      'divorced': l10n.maritalStatusDivorced,
      'widowed': l10n.maritalStatusWidowed,
      'separated': l10n.maritalStatusSeparated,
      'married': l10n.maritalStatusMarried,
    }[value] ?? (value ?? '');

// Same 5 values/order as the old maritalStatusOptions const (nikah_step1_
// screen.dart) — used by both the registration wizard and the Browse
// filter's marital-status dropdowns, which were hardcoded English-only.
Map<String, String> maritalStatusOptions(AppLocalizations l10n) => {
      'never_married': l10n.maritalStatusNeverMarried,
      'divorced': l10n.maritalStatusDivorced,
      'widowed': l10n.maritalStatusWidowed,
      'married': l10n.maritalStatusMarried,
      'separated': l10n.maritalStatusSeparated,
    };

String counselorTierLabel(AppLocalizations l10n, String? tier) => {
      'nikah_counselor': l10n.nikahTierNikahCounselor,
      'certified_nikah_counselor': l10n.nikahTierCertifiedNikahCounselor,
      'senior_nikah_counselor': l10n.nikahTierSeniorNikahCounselor,
      'regional_nikah_coordinator': l10n.nikahTierRegionalNikahCoordinator,
    }[tier] ?? l10n.nikahTierNikahCounselor;
