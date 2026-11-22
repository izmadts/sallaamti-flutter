import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/module_themes.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/required_label.dart';
import '../../../../shared/widgets/step_wizard_scaffold.dart';
import '../../domain/nikah_labels.dart';
import '../../domain/nikah_profile.dart';
import '../../state/nikah_controller.dart';

// Public (no leading underscore) — reused by nikah_step3_screen.dart so
// "Preferred Sect"/"Preferred Education" offer the exact same options as
// these, instead of asking for the same fixed value as free text. The
// stored/API value is always this literal English string (matching the
// backend's validation and web's own dropdowns exactly) — only the
// DISPLAYED label is translated, via sectLabel()/educationLabel() in
// nikah_labels.dart, never these lists themselves.
const sectOptions = ['Sunni', 'Shia', 'Ahle Hadith', 'Deobandi', 'Other'];
// Matches web's step-basic.blade.php $educationLevels exactly.
const educationLevels = [
  'Matric / O-Levels',
  'Intermediate / A-Levels',
  "Bachelor's",
  "Master's",
  'MPhil / MS',
  'PhD',
  'Madrassah / Islamic Education',
];
// Social-class terms, not household structure (owner, 21 Nov 2026):
// "joint/nuclear logo ko samajh nahi aati" — members didn't understand the
// old Joint Family/Nuclear Family wording, so this field now describes
// family social standing instead. Same change on the web wizard. Stored
// value stays this literal English string — see familyTypeLabel().
const _familyTypeOptions = ['Elite', 'High Class', 'Middle', 'Lower Middle', 'Other'];
const _commonLanguages = [
  'Urdu',
  'English',
  'Punjabi',
  'Sindhi',
  'Pashto',
  'Saraiki',
  'Balochi',
];

class NikahStep2Screen extends ConsumerStatefulWidget {
  const NikahStep2Screen({super.key});

  @override
  ConsumerState<NikahStep2Screen> createState() => _NikahStep2ScreenState();
}

class _NikahStep2ScreenState extends ConsumerState<NikahStep2Screen> {
  final _sectOtherController = TextEditingController();
  final _casteController = TextEditingController();
  final _familyTypeOtherController = TextEditingController();
  final _ethnicityController = TextEditingController();
  final _professionController = TextEditingController();
  final _languageOtherController = TextEditingController();

  String? _sect;
  String? _education;
  String? _prayerFrequency;
  String? _hijabOrBeard;
  String? _smokes;
  String? _diet;
  String? _familyType;
  bool _openToPolygamy = false;
  final Set<String> _languages = {};
  bool _busy = false;
  String? _error;
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    // Same race condition as nikah_step1_screen.dart (see its comment) —
    // nikahControllerProvider's profile fetch can still be in flight when
    // this screen first mounts; build()'s ref.listen below catches that
    // case. This initState() call only covers the common case: the
    // profile already loaded by the time someone reaches step 2.
    final profile = ref.read(nikahControllerProvider).profile;
    if (profile != null) _prefillFrom(profile);
  }

  void _prefillFrom(NikahProfile profile) {
    _prefilled = true;
    _casteController.text = profile.caste ?? '';
    _ethnicityController.text = profile.ethnicity ?? '';
    _education = (profile.education?.isNotEmpty ?? false)
        ? profile.education
        : null;
    _professionController.text = profile.profession ?? '';
    _openToPolygamy = profile.openToPolygamy ?? false;
    // Found live (16 Nov 2026) — these four were never restored at all,
    // race condition or not: the code to read them back from `profile`
    // was simply never written, so they showed blank on every single edit.
    _prayerFrequency = profile.prayerFrequency;
    _hijabOrBeard = profile.hijabOrBeard;
    _smokes = profile.smokes;
    _diet = profile.diet;

    if (profile.sect != null && profile.sect!.isNotEmpty) {
      if (sectOptions.contains(profile.sect)) {
        _sect = profile.sect;
      } else {
        _sect = 'Other';
        _sectOtherController.text = profile.sect!;
      }
    }

    if (profile.familyType != null && profile.familyType!.isNotEmpty) {
      if (_familyTypeOptions.contains(profile.familyType)) {
        _familyType = profile.familyType;
      } else {
        _familyType = 'Other';
        _familyTypeOtherController.text = profile.familyType!;
      }
    }

    // Reverses ValidatesNikahProfile::resolveLanguage() on the backend —
    // the common ones selected from the checklist plus one free-text
    // "other" entry, joined with ', '.
    if (profile.language != null && profile.language!.isNotEmpty) {
      for (final part in profile.language!.split(',')) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        if (_commonLanguages.contains(trimmed)) {
          _languages.add(trimmed);
        } else {
          _languageOtherController.text = trimmed;
        }
      }
    }
  }

  @override
  void dispose() {
    _sectOtherController.dispose();
    _casteController.dispose();
    _familyTypeOtherController.dispose();
    _ethnicityController.dispose();
    _professionController.dispose();
    _languageOtherController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final l10n = AppLocalizations.of(context)!;

    if (_sect == null || _sect!.isEmpty) {
      setState(() => _error = l10n.nikahPleaseSelectSect);
      return;
    }
    if (_education == null || _education!.isEmpty) {
      setState(() => _error = l10n.nikahPleaseSelectEducation);
      return;
    }
    if (_professionController.text.trim().isEmpty) {
      setState(() => _error = l10n.nikahPleaseEnterProfession);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(nikahControllerProvider.notifier).save({
        'sect': _sect,
        'sect_other': _sect == 'Other'
            ? _sectOtherController.text.trim()
            : null,
        'caste': _casteController.text.trim(),
        'prayer_frequency': _prayerFrequency,
        'hijab_or_beard': _hijabOrBeard,
        'smokes': _smokes,
        'diet': _diet,
        'open_to_polygamy': _openToPolygamy,
        'family_type': _familyType == 'Other'
            ? _familyTypeOtherController.text.trim()
            : _familyType,
        'ethnicity': _ethnicityController.text.trim(),
        'education': _education,
        'profession': _professionController.text.trim(),
        'languages': _languages.toList(),
        'language_other': _languageOtherController.text.trim(),
      });
      if (mounted) context.push('/nikah/wizard/step3');
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!_prefilled) {
      ref.listen(nikahControllerProvider, (previous, next) {
        if (next.profile != null && !_prefilled) {
          setState(() => _prefillFrom(next.profile!));
        }
      });
    }

    return StepWizardScaffold(
      title: l10n.nikahDeenLifestyleTitle,
      stepIndex: 1,
      totalSteps: 5,
      nextLabel: l10n.nikahNextAboutPreferences,
      onNext: _next,
      busy: _busy,
      theme: ModuleThemes.forModule('nikah'),
      errorText: _error,
      onBack: () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.nikahStep2IntroMessage,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _sect,
            decoration: InputDecoration(label: requiredLabel(l10n.sectLabel)),
            items: sectOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(sectLabel(l10n, s))))
                .toList(),
            onChanged: (v) => setState(() => _sect = v),
          ),
          if (_sect == 'Other') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _sectOtherController,
              decoration: InputDecoration(labelText: l10n.nikahEnterSectLabel),
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _prayerFrequency,
            decoration: InputDecoration(
              labelText: l10n.nikahPrayerFrequencyLabel,
            ),
            items: prayerOptions(l10n).entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => _prayerFrequency = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _hijabOrBeard,
            decoration: InputDecoration(labelText: l10n.hijabBeardLabel),
            items: hijabBeardOptions(l10n).entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => _hijabOrBeard = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _smokes,
            decoration: InputDecoration(labelText: l10n.nikahSmokingLabel),
            items: smokesOptions(l10n).entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => _smokes = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _diet,
            decoration: InputDecoration(labelText: l10n.dietLabel),
            items: dietOptions(l10n).entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => _diet = v),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.nikahOpenToPolygamyLabel),
            value: _openToPolygamy,
            onChanged: (v) => setState(() => _openToPolygamy = v),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.nikahBackgroundTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _casteController,
            decoration: InputDecoration(labelText: l10n.casteLabel),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _familyType,
            decoration: InputDecoration(labelText: l10n.familyTypeLabel),
            items: _familyTypeOptions
                .map((f) => DropdownMenuItem(value: f, child: Text(familyTypeLabel(l10n, f))))
                .toList(),
            onChanged: (v) => setState(() => _familyType = v),
          ),
          if (_familyType == 'Other') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _familyTypeOtherController,
              decoration: InputDecoration(labelText: l10n.nikahEnterFamilyTypeLabel),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _ethnicityController,
            decoration: InputDecoration(labelText: l10n.ethnicityLabel),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _education,
            decoration: InputDecoration(label: requiredLabel(l10n.educationLabel)),
            items: educationLevels
                .map((e) => DropdownMenuItem(value: e, child: Text(educationLabel(l10n, e))))
                .toList(),
            onChanged: (v) => setState(() => _education = v),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _professionController,
            decoration: InputDecoration(label: requiredLabel(l10n.professionLabel)),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.nikahLanguagesSpokenLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Wrap(
            spacing: 8,
            children: _commonLanguages.map((lang) {
              final selected = _languages.contains(lang);
              return FilterChip(
                label: Text(languageLabel(l10n, lang)),
                selected: selected,
                onSelected: (v) => setState(
                  () => v ? _languages.add(lang) : _languages.remove(lang),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _languageOtherController,
            decoration: InputDecoration(labelText: l10n.nikahOtherLanguageLabel),
          ),
        ],
      ),
    );
  }
}
