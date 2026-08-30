import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/data/country_states_repository.dart';
import '../../../../core/theme/module_themes.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/required_label.dart';
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

// Matches web's nikah/edit.blade.php $guardianRelOptions exactly, plus
// "Other" as an app-only escape hatch for anything not in that list.
const _guardianRelationOptions = ['Self', 'Father', 'Mother', 'Brother', 'Sister', 'Uncle', 'Aunt', 'Grandfather', 'Grandmother', 'Other'];

class NikahStep1Screen extends ConsumerStatefulWidget {
  const NikahStep1Screen({super.key});

  @override
  ConsumerState<NikahStep1Screen> createState() => _NikahStep1ScreenState();
}

class _NikahStep1ScreenState extends ConsumerState<NikahStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _heightOtherController = TextEditingController();
  final _cityController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianContactController = TextEditingController();
  final _guardianRelationOtherController = TextEditingController();

  String? _gender;
  DateTime? _dateOfBirth;
  String? _height;
  String _maritalStatus = 'never_married';
  String _country = 'Pakistan';
  String? _state;
  String? _guardianRelation;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _heightOtherController.dispose();
    _cityController.dispose();
    _guardianNameController.dispose();
    _guardianContactController.dispose();
    _guardianRelationOtherController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Date of Birth',
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _next() async {
    final l10n = AppLocalizations.of(context)!;

    if (_gender == null) {
      setState(() => _error = l10n.nikahSelectGender);
      return;
    }
    if (_dateOfBirth == null) {
      setState(() => _error = 'Please select your date of birth');
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
        'date_of_birth': '${_dateOfBirth!.year.toString().padLeft(4, '0')}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}',
        'height': _height,
        'height_other': _height == 'Other' ? _heightOtherController.text.trim() : null,
        'marital_status': _maritalStatus,
        'city': _cityController.text.trim(),
        'state': _state,
        'country': _country,
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

  Future<void> _pickCountry(List<String> allCountries) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SearchablePicker(title: 'Select Country', options: allCountries, initialValue: _country),
    );
    if (selected != null) {
      setState(() {
        _country = selected;
        _state = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final countryStatesAsync = ref.watch(countryStatesProvider);

    return StepWizardScaffold(
      title: 'Basic Info',
      stepIndex: 0,
      totalSteps: 5,
      nextLabel: 'Next: Deen & Lifestyle',
      onNext: _next,
      busy: _busy,
      errorText: _error,
      theme: ModuleThemes.forModule('nikah'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        const Text('Tell us about yourself', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        _GenderPicker(value: _gender, onChanged: (v) => setState(() => _gender = v)),
        const SizedBox(height: 16),
        InkWell(
          onTap: _pickDateOfBirth,
          child: InputDecorator(
            decoration: InputDecoration(label: requiredLabel('Date of Birth')),
            child: Text(
              _dateOfBirth == null
                  ? 'Select date'
                  : '${_dateOfBirth!.year.toString().padLeft(4, '0')}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}',
            ),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _height,
          decoration: const InputDecoration(labelText: 'Height'),
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
          decoration: InputDecoration(label: requiredLabel('Marital Status')),
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
          decoration: InputDecoration(label: requiredLabel('City')),
          validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
        ),
        const SizedBox(height: 16),
        countryStatesAsync.when(
          data: (cs) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => _pickCountry(cs.countries),
                child: InputDecorator(
                  decoration: InputDecoration(label: requiredLabel('Country')),
                  child: Text(_country),
                ),
              ),
              const SizedBox(height: 16),
              if (cs.statesFor(_country).isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _state,
                  decoration: const InputDecoration(labelText: 'State / Province'),
                  items: cs.statesFor(_country).map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _state = v),
                ),
            ],
          ),
          loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()),
          error: (error, stack) => TextFormField(
            initialValue: _country,
            decoration: InputDecoration(label: requiredLabel('Country')),
            onChanged: (v) => _country = v,
          ),
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
          decoration: InputDecoration(label: requiredLabel('Guardian Name')),
          validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _guardianContactController,
          decoration: InputDecoration(label: requiredLabel('Guardian Phone Number')),
          keyboardType: TextInputType.phone,
          validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _guardianRelation,
          decoration: const InputDecoration(labelText: 'Relation'),
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

class _SearchablePicker extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? initialValue;
  const _SearchablePicker({required this.title, required this.options, this.initialValue});

  @override
  State<_SearchablePicker> createState() => _SearchablePickerState();
}

class _SearchablePickerState extends State<_SearchablePicker> {
  final _searchController = TextEditingController();
  late List<String> _filtered = widget.options;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? widget.options
          : widget.options.where((o) => o.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(hintText: 'Search…', prefixIcon: Icon(Icons.search)),
                autofocus: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final option = _filtered[index];
                  return ListTile(
                    title: Text(option),
                    selected: option == widget.initialValue,
                    onTap: () => Navigator.of(context).pop(option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
