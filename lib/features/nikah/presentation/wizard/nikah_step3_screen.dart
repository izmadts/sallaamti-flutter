import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/module_themes.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/required_label.dart';
import '../../../../shared/widgets/step_wizard_scaffold.dart';
import '../../state/nikah_controller.dart';
import 'nikah_step1_screen.dart' show maritalStatusOptions;
import 'nikah_step2_screen.dart' show sectOptions, educationLevels;

class NikahStep3Screen extends ConsumerStatefulWidget {
  const NikahStep3Screen({super.key});

  @override
  ConsumerState<NikahStep3Screen> createState() => _NikahStep3ScreenState();
}

class _NikahStep3ScreenState extends ConsumerState<NikahStep3Screen> {
  final _aboutController = TextEditingController();
  final _expectationsController = TextEditingController();
  final _prefMinAgeController = TextEditingController();
  final _prefMaxAgeController = TextEditingController();
  final _prefCityController = TextEditingController();
  final _prefIncomeController = TextEditingController();
  final _prefOtherController = TextEditingController();
  // Dropdowns (not free text) — "Preferred Sect"/"Preferred Education"
  // offer the exact same fixed options as the profile's own Sect/Education
  // fields above, instead of asking for the same value typed out again.
  String? _prefSect;
  String? _prefEducation;
  String? _prefMaritalStatus;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(nikahControllerProvider).profile;
    if (profile != null) {
      _aboutController.text = profile.about ?? '';
      _expectationsController.text = profile.expectations ?? '';
      _prefMinAgeController.text = profile.prefMinAge?.toString() ?? '';
      _prefMaxAgeController.text = profile.prefMaxAge?.toString() ?? '';
      _prefCityController.text = profile.prefCity ?? '';
      // Falls back to "Any" (null) if a previously-saved free-text value
      // (from before this was a dropdown) doesn't match one of the fixed
      // options — avoids a Flutter error from an initialValue that isn't
      // actually one of the dropdown's items.
      _prefSect = sectOptions.contains(profile.prefSect) ? profile.prefSect : null;
      _prefEducation = educationLevels.contains(profile.prefEducation) ? profile.prefEducation : null;
      _prefIncomeController.text = profile.prefIncome ?? '';
      _prefOtherController.text = profile.prefOther ?? '';
      _prefMaritalStatus = profile.prefMaritalStatus;
    }
  }

  @override
  void dispose() {
    _aboutController.dispose();
    _expectationsController.dispose();
    _prefMinAgeController.dispose();
    _prefMaxAgeController.dispose();
    _prefCityController.dispose();
    _prefIncomeController.dispose();
    _prefOtherController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final l10n = AppLocalizations.of(context)!;

    if (_expectationsController.text.trim().isEmpty) {
      setState(
        () => _error = 'Please tell us what you\'re looking for in a partner',
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(nikahControllerProvider.notifier).save({
        'about': _aboutController.text.trim(),
        'expectations': _expectationsController.text.trim(),
        'pref_min_age': _prefMinAgeController.text.trim(),
        'pref_max_age': _prefMaxAgeController.text.trim(),
        'pref_city': _prefCityController.text.trim(),
        'pref_sect': _prefSect,
        'pref_education': _prefEducation,
        'pref_marital_status': _prefMaritalStatus,
        'pref_income': _prefIncomeController.text.trim(),
        'pref_other': _prefOtherController.text.trim(),
      });
      if (mounted) context.push('/nikah/wizard/step4');
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
      title: 'About & Preferences',
      stepIndex: 2,
      totalSteps: 5,
      nextLabel: 'Next: Photos & Verification',
      onNext: _next,
      busy: _busy,
      theme: ModuleThemes.forModule('nikah'),
      errorText: _error,
      onBack: () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'In your own words',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _aboutController,
            decoration: const InputDecoration(labelText: 'About yourself'),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _expectationsController,
            decoration: InputDecoration(
              label: requiredLabel('What are you looking for?'),
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 24),
          const Text(
            'Partner Preferences',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Used to show your match % with other profiles.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _prefMinAgeController,
                  decoration: const InputDecoration(labelText: 'Min age'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _prefMaxAgeController,
                  decoration: const InputDecoration(labelText: 'Max age'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _prefCityController,
            decoration: const InputDecoration(labelText: 'Preferred city'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _prefSect,
            decoration: const InputDecoration(labelText: 'Preferred sect'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Any')),
              ...sectOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))),
            ],
            onChanged: (v) => setState(() => _prefSect = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _prefEducation,
            decoration: const InputDecoration(labelText: 'Preferred education'),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('Any')),
              ...educationLevels.map((e) => DropdownMenuItem(value: e, child: Text(e))),
            ],
            onChanged: (v) => setState(() => _prefEducation = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _prefMaritalStatus,
            decoration: const InputDecoration(
              labelText: 'Preferred marital status',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Any')),
              ...maritalStatusOptions.entries.map(
                (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
              ),
            ],
            onChanged: (v) => setState(() => _prefMaritalStatus = v),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _prefIncomeController,
            decoration: const InputDecoration(
              labelText: 'Preferred income / business worth',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _prefOtherController,
            decoration: const InputDecoration(labelText: 'Other preferences'),
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
