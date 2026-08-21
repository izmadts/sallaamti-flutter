import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/step_wizard_scaffold.dart';
import '../../state/nikah_controller.dart';

// Heights 4'0" to 7'0", matching the height-range filter the browse
// endpoint already supports on the backend.
List<String> _heightOptions() {
  final options = <String>[];
  for (var ft = 4; ft <= 7; ft++) {
    for (var inch = 0; inch <= 11; inch++) {
      if (ft == 7 && inch > 0) break;
      options.add('$ft\'$inch"');
    }
  }
  options.add('Other');
  return options;
}

const maritalStatusOptions = {
  'never_married': 'Never Married',
  'divorced': 'Divorced',
  'widowed': 'Widowed',
  'married': 'Married',
  'separated': 'Separated',
};

const _guardianRelationOptions = ['Father', 'Mother', 'Brother', 'Uncle', 'Other'];

class NikahStep1Screen extends ConsumerStatefulWidget {
  const NikahStep1Screen({super.key});

  @override
  ConsumerState<NikahStep1Screen> createState() => _NikahStep1ScreenState();
}

class _NikahStep1ScreenState extends ConsumerState<NikahStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _heightOtherController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController(text: 'Pakistan');
  final _guardianNameController = TextEditingController();
  final _guardianContactController = TextEditingController();
  final _guardianRelationOtherController = TextEditingController();

  String? _gender;
  String? _height;
  String _maritalStatus = 'never_married';
  String? _guardianRelation;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ageController.dispose();
    _heightOtherController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _guardianNameController.dispose();
    _guardianContactController.dispose();
    _guardianRelationOtherController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final l10n = AppLocalizations.of(context)!;

    if (_gender == null) {
      setState(() => _error = l10n.nikahSelectGender);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(nikahControllerProvider.notifier).save({
        'gender': _gender,
        'age': _ageController.text.trim(),
        'height': _height,
        'height_other': _height == 'Other' ? _heightOtherController.text.trim() : null,
        'marital_status': _maritalStatus,
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'country': _countryController.text.trim(),
        'guardian_name': _guardianNameController.text.trim(),
        'guardian_contact': _guardianContactController.text.trim(),
        'guardian_relation': _guardianRelation == 'Other' ? _guardianRelationOtherController.text.trim() : _guardianRelation,
      });
      if (mounted) context.push('/nikah/wizard/step2');
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
    return StepWizardScaffold(
      title: 'Basic Info',
      stepIndex: 0,
      totalSteps: 5,
      nextLabel: 'Next: Deen & Lifestyle',
      onNext: _next,
      busy: _busy,
      errorText: _error,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        const Text('Tell us about yourself', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        _GenderPicker(value: _gender, onChanged: (v) => setState(() => _gender = v)),
        const SizedBox(height: 16),
        TextFormField(
          controller: _ageController,
          decoration: const InputDecoration(labelText: 'Age'),
          keyboardType: TextInputType.number,
          validator: (v) {
            final n = int.tryParse(v ?? '');
            if (n == null || n < 18 || n > 70) return 'Enter an age between 18 and 70';
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _height,
          decoration: const InputDecoration(labelText: 'Height (optional)'),
          items: _heightOptions().map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
          onChanged: (v) => setState(() => _height = v),
        ),
        if (_height == 'Other') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _heightOtherController,
            decoration: const InputDecoration(labelText: 'Enter height'),
          ),
        ],
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _maritalStatus,
          decoration: const InputDecoration(labelText: 'Marital Status'),
          items: maritalStatusOptions.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => _maritalStatus = v!),
        ),
        const SizedBox(height: 24),
        const Text('Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextFormField(
          controller: _cityController,
          decoration: const InputDecoration(labelText: 'City'),
          validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _stateController,
          decoration: const InputDecoration(labelText: 'State / Province (optional)'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _countryController,
          decoration: const InputDecoration(labelText: 'Country'),
        ),
        const SizedBox(height: 24),
        const Text('Guardian (Wali)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Required for Nikah profiles — your guardian is your point of contact for serious matches.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _guardianNameController,
          decoration: const InputDecoration(labelText: 'Guardian Name'),
          validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _guardianContactController,
          decoration: const InputDecoration(labelText: 'Guardian Phone Number'),
          keyboardType: TextInputType.phone,
          validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _guardianRelation,
          decoration: const InputDecoration(labelText: 'Relation (optional)'),
          items: _guardianRelationOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (v) => setState(() => _guardianRelation = v),
        ),
        if (_guardianRelation == 'Other') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _guardianRelationOtherController,
            decoration: const InputDecoration(labelText: 'Enter relation'),
          ),
        ],
          ],
        ),
      ),
    );
  }
}

class _GenderPicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  const _GenderPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _GenderTile(label: 'Male', emoji: '👨', selected: value == 'male', onTap: () => onChanged('male'))),
        const SizedBox(width: 12),
        Expanded(child: _GenderTile(label: 'Female', emoji: '👩', selected: value == 'female', onTap: () => onChanged('female'))),
      ],
    );
  }
}

class _GenderTile extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  const _GenderTile({required this.label, required this.emoji, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          border: Border.all(color: selected ? color : Colors.grey.shade300, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? color : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
