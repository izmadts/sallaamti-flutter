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

Map<String, String> livingSituationOptions(AppLocalizations l10n) => {
      'alone': l10n.nikahLivingAlone,
      'with_mother': l10n.nikahLivingWithMother,
      'with_father': l10n.nikahLivingWithFather,
      'with_maternal_grandparents': l10n.nikahLivingWithMaternalGrandparents,
      'with_paternal_grandparents': l10n.nikahLivingWithPaternalGrandparents,
      'with_children': l10n.nikahLivingWithChildren,
      'other': l10n.otherLabel,
    };

// The stored value for guardian_relation is the literal English word
// itself (no separate code, matching web's own $guardianRelOptions) — so
// this only translates the DISPLAYED label, the list of underlying values
// sent to the backend is unchanged.
const guardianRelationValues = ['Self', 'Father', 'Mother', 'Brother', 'Sister', 'Uncle', 'Aunt', 'Grandfather', 'Grandmother', 'Other'];

String guardianRelationLabel(AppLocalizations l10n, String value) => {
      'Self': l10n.guardianRelationSelf,
      'Father': l10n.guardianRelationFather,
      'Mother': l10n.guardianRelationMother,
      'Brother': l10n.guardianRelationBrother,
      'Sister': l10n.guardianRelationSister,
      'Uncle': l10n.guardianRelationUncle,
      'Aunt': l10n.guardianRelationAunt,
      'Grandfather': l10n.guardianRelationGrandfather,
      'Grandmother': l10n.guardianRelationGrandmother,
      'Other': l10n.otherLabel,
    }[value] ?? value;

// The following all store the literal English value in the DB (matching
// the backend's own validation rules / web's dropdowns exactly) — only the
// DISPLAYED label is translated, never the value sent to the API.
String sectLabel(AppLocalizations l10n, String value) => {
      'Sunni': l10n.sectSunni,
      'Shia': l10n.sectShia,
      'Ahle Hadith': l10n.sectAhleHadith,
      'Deobandi': l10n.sectDeobandi,
      'Other': l10n.otherLabel,
    }[value] ?? value;

String educationLabel(AppLocalizations l10n, String value) => {
      'Matric / O-Levels': l10n.educationMatric,
      'Intermediate / A-Levels': l10n.educationIntermediate,
      "Bachelor's": l10n.educationBachelors,
      "Master's": l10n.educationMasters,
      'MPhil / MS': l10n.educationMphil,
      'PhD': l10n.educationPhd,
      'Madrassah / Islamic Education': l10n.educationMadrassah,
    }[value] ?? value;

Map<String, String> prayerOptions(AppLocalizations l10n) => {
      'always': l10n.prayerAlways,
      'usually': l10n.prayerUsually,
      'sometimes': l10n.prayerSometimes,
      'rarely': l10n.prayerRarely,
    };

Map<String, String> hijabBeardOptions(AppLocalizations l10n) => {
      'yes': l10n.hijabBeardYes,
      'no': l10n.hijabBeardNo,
      'sometimes': l10n.hijabBeardSometimes,
    };

Map<String, String> smokesOptions(AppLocalizations l10n) => {
      'no': l10n.smokesNo,
      'occasionally': l10n.smokesOccasionally,
      'yes': l10n.smokesYes,
    };

Map<String, String> dietOptions(AppLocalizations l10n) => {
      'halal_only': l10n.dietHalalOnly,
      'halal_mostly': l10n.dietHalalMostly,
      'no_restriction': l10n.dietNoRestriction,
    };

String familyTypeLabel(AppLocalizations l10n, String value) => {
      'Elite': l10n.familyTypeElite,
      'High Class': l10n.familyTypeHighClass,
      'Middle': l10n.familyTypeMiddle,
      'Lower Middle': l10n.familyTypeLowerMiddle,
      'Other': l10n.otherLabel,
    }[value] ?? value;

String languageLabel(AppLocalizations l10n, String value) => {
      'Urdu': l10n.languageUrdu,
      'English': l10n.languageEnglish,
      'Punjabi': l10n.languagePunjabi,
      'Sindhi': l10n.languageSindhi,
      'Pashto': l10n.languagePashto,
      'Saraiki': l10n.languageSaraiki,
      'Balochi': l10n.languageBalochi,
    }[value] ?? value;

String visibilityLabel(AppLocalizations l10n, String? value) => {
      'public': l10n.nikahVisibilityPublic,
      'members_only': l10n.nikahVisibilityMembersOnly,
      'matchmaker_assisted': l10n.nikahVisibilityMatchmakerAssisted,
      'confidential': l10n.nikahVisibilityConfidential,
    }[value] ?? (value ?? '');

String interestStatusLabel(AppLocalizations l10n, String status) => {
      'pending': l10n.interestStatusPending,
      'accepted': l10n.interestStatusAccepted,
      'declined': l10n.interestStatusDeclined,
      'blocked': l10n.interestStatusBlocked,
    }[status] ?? status;

String counselorTierLabel(AppLocalizations l10n, String? tier) => {
      'nikah_counselor': l10n.nikahTierNikahCounselor,
      'certified_nikah_counselor': l10n.nikahTierCertifiedNikahCounselor,
      'senior_nikah_counselor': l10n.nikahTierSeniorNikahCounselor,
      'regional_nikah_coordinator': l10n.nikahTierRegionalNikahCoordinator,
    }[tier] ?? l10n.nikahTierNikahCounselor;
