import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/step_wizard_scaffold.dart';
import '../../state/nikah_controller.dart';

const _sectOptions = ['Sunni', 'Shia', 'Ahle Hadith', 'Deobandi', 'Other'];
const _prayerOptions = {
  'always': 'Always (5x daily)',
  'usually': 'Usually',
  'sometimes': 'Sometimes',
  'rarely': 'Rarely',
};
const _hijabBeardOptions = {'yes': 'Yes', 'no': 'No', 'sometimes': 'Sometimes'};
const _smokesOptions = {'no': 'No', 'occasionally': 'Occasionally', 'yes': 'Yes'};
const _dietOptions = {
  'halal_only': 'Halal only',
  'halal_mostly': 'Mostly halal',
  'no_restriction': 'No restriction',
};
const _familyTypeOptions = ['Joint Family', 'Nuclear Family', 'Other'];
const _commonLanguages = ['Urdu', 'English', 'Punjabi', 'Sindhi', 'Pashto', 'Saraiki', 'Balochi'];

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
  final _educationController = TextEditingController();
  final _professionController = TextEditingController();
  final _languageOtherController = TextEditingController();

  String? _sect;
  String? _prayerFrequency;
  String? _hijabOrBeard;
  String? _smokes;
  String? _diet;
  String? _familyType;
  bool _openToPolygamy = false;
  final Set<String> _languages = {};
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(nikahControllerProvider).profile;
    if (profile != null) {
      _casteController.text = profile.caste ?? '';
      _ethnicityController.text = profile.ethnicity ?? '';
      _educationController.text = profile.education ?? '';
      _professionController.text = profile.profession ?? '';
      _openToPolygamy = profile.openToPolygamy ?? false;
      _familyType = profile.familyType;
    }
  }

  @override
  void dispose() {
    _sectOtherController.dispose();
    _casteController.dispose();
    _familyTypeOtherController.dispose();
    _ethnicityController.dispose();
    _educationController.dispose();
    _professionController.dispose();
    _languageOtherController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(nikahControllerProvider.notifier).save({
        'sect': _sect,
        'sect_other': _sect == 'Other' ? _sectOtherController.text.trim() : null,
        'caste': _casteController.text.trim(),
        'prayer_frequency': _prayerFrequency,
        'hijab_or_beard': _hijabOrBeard,
        'smokes': _smokes,
        'diet': _diet,
        'open_to_polygamy': _openToPolygamy,
        'family_type': _familyType == 'Other' ? _familyTypeOtherController.text.trim() : _familyType,
        'ethnicity': _ethnicityController.text.trim(),
        'education': _educationController.text.trim(),
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
    return StepWizardScaffold(
      title: 'Deen & Lifestyle',
      stepIndex: 1,
      totalSteps: 5,
      nextLabel: 'Next: About & Preferences',
      onNext: _next,
      busy: _busy,
      errorText: _error,
      onBack: () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Everything here is optional — share what you\'re comfortable with', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _sect,
            decoration: const InputDecoration(labelText: 'Sect'),
            items: _sectOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _sect = v),
          ),
          if (_sect == 'Other') ...[
            const SizedBox(height: 12),
            TextFormField(controller: _sectOtherController, decoration: const InputDecoration(labelText: 'Enter sect')),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _prayerFrequency,
            decoration: const InputDecoration(labelText: 'How often do you pray?'),
            items: _prayerOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _prayerFrequency = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _hijabOrBeard,
            decoration: const InputDecoration(labelText: 'Hijab / Beard'),
            items: _hijabBeardOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _hijabOrBeard = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _smokes,
            decoration: const InputDecoration(labelText: 'Smoking'),
            items: _smokesOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _smokes = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _diet,
            decoration: const InputDecoration(labelText: 'Diet'),
            items: _dietOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _diet = v),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Open to polygamy'),
            value: _openToPolygamy,
            onChanged: (v) => setState(() => _openToPolygamy = v),
          ),
          const SizedBox(height: 16),
          const Text('Background', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextFormField(controller: _casteController, decoration: const InputDecoration(labelText: 'Caste (optional)')),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _familyType,
            decoration: const InputDecoration(labelText: 'Family Type'),
            items: _familyTypeOptions.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (v) => setState(() => _familyType = v),
          ),
          if (_familyType == 'Other') ...[
            const SizedBox(height: 12),
            TextFormField(controller: _familyTypeOtherController, decoration: const InputDecoration(labelText: 'Enter family type')),
          ],
          const SizedBox(height: 16),
          TextFormField(controller: _ethnicityController, decoration: const InputDecoration(labelText: 'Ethnicity (optional)')),
          const SizedBox(height: 16),
          TextFormField(controller: _educationController, decoration: const InputDecoration(labelText: 'Education (optional)')),
          const SizedBox(height: 16),
          TextFormField(controller: _professionController, decoration: const InputDecoration(labelText: 'Profession (optional)')),
          const SizedBox(height: 16),
          const Text('Languages Spoken', style: TextStyle(fontWeight: FontWeight.w600)),
          Wrap(
            spacing: 8,
            children: _commonLanguages.map((lang) {
              final selected = _languages.contains(lang);
              return FilterChip(
                label: Text(lang),
                selected: selected,
                onSelected: (v) => setState(() => v ? _languages.add(lang) : _languages.remove(lang)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _languageOtherController,
            decoration: const InputDecoration(labelText: 'Other language (optional)'),
          ),
        ],
      ),
    );
  }
}
