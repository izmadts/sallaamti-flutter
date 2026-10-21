import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'dart:async';

import '../../../../core/api/api_exception.dart';
import '../../../../core/data/city_search_repository.dart';
import '../../../../core/data/country_states_repository.dart';
import '../../../../core/theme/module_themes.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/required_label.dart';
import '../../../../shared/widgets/step_wizard_scaffold.dart';
import '../../../../shared/widgets/whatsapp_channel_action.dart';
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

// Matches ValidatesNikahProfile's required_if list on the backend — these
// three fields were missing from the mobile wizard entirely (never shown,
// never sent), so a divorced/widowed/separated/married member could finish
// on mobile with none of this recorded, unlike web. Public (no leading
// underscore) — nikah_home_screen.dart reuses it to decide whether these
// fields count toward "is this profile actually finished".
const needsFamilyDetailsStatuses = ['divorced', 'widowed', 'separated', 'married'];

const _livingSituationOptions = {
  'alone': 'Alone',
  'with_mother': 'With Mother',
  'with_father': 'With Father',
  'with_maternal_grandparents': 'With Maternal Grandparents',
  'with_paternal_grandparents': 'With Paternal Grandparents',
  'with_children': 'With My Children',
  'other': 'Other',
};

// Matches web's nikah/edit.blade.php $guardianRelOptions exactly, plus
// "Other" as an app-only escape hatch for anything not in that list.
const _guardianRelationOptions = [
  'Self',
  'Father',
  'Mother',
  'Brother',
  'Sister',
  'Uncle',
  'Aunt',
  'Grandfather',
  'Grandmother',
  'Other',
];

class NikahStep1Screen extends ConsumerStatefulWidget {
  const NikahStep1Screen({super.key});

  @override
  ConsumerState<NikahStep1Screen> createState() => _NikahStep1ScreenState();
}

class _NikahStep1ScreenState extends ConsumerState<NikahStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _heightOtherController = TextEditingController();
  final _addressController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianContactController = TextEditingController();
  final _guardianRelationOtherController = TextEditingController();
  final _childrenCountController = TextEditingController();

  String? _gender;
  DateTime? _dateOfBirth;
  String? _height;
  String _maritalStatus = 'never_married';
  bool? _hasChildren;
  String? _livingSituation;
  String _country = 'Pakistan';
  String? _state;
  String? _city;
  String? _guardianRelation;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(nikahControllerProvider).profile;
    if (profile == null) return;

    _gender = profile.gender;
    _dateOfBirth = profile.dateOfBirth;
    _maritalStatus = profile.maritalStatus;
    _hasChildren = profile.hasChildren;
    _livingSituation = profile.livingSituation;
    if (profile.childrenCount != null) {
      _childrenCountController.text = profile.childrenCount.toString();
    }
    _country = profile.country?.isNotEmpty == true ? profile.country! : 'Pakistan';
    _state = profile.state;
    _city = profile.city;
    _addressController.text = profile.address ?? '';
    _guardianNameController.text = profile.guardianName ?? '';
    _guardianContactController.text = profile.guardianContact ?? '';

    if (profile.height != null && profile.height!.isNotEmpty) {
      if (_heightOptions().contains(profile.height)) {
        _height = profile.height;
      } else {
        _height = 'Other';
        _heightOtherController.text = profile.height!;
      }
    }

    if (profile.guardianRelation != null && profile.guardianRelation!.isNotEmpty) {
      if (_guardianRelationOptions.contains(profile.guardianRelation)) {
        _guardianRelation = profile.guardianRelation;
      } else {
        _guardianRelation = 'Other';
        _guardianRelationOtherController.text = profile.guardianRelation!;
      }
    }
  }

  @override
  void dispose() {
    _heightOtherController.dispose();
    _addressController.dispose();
    _guardianNameController.dispose();
    _guardianContactController.dispose();
    _guardianRelationOtherController.dispose();
    _childrenCountController.dispose();
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
    if (_height == null || _height!.trim().isEmpty) {
      setState(() => _error = 'Please select your height');
      return;
    }
    // State is only genuinely optional when the picked country has no
    // states/provinces in our data at all — matches the web forms' same
    // "required unless the field can't apply" treatment.
    final hasStates = (ref.read(countryStatesProvider).valueOrNull?.statesFor(_country) ?? []).isNotEmpty;
    if (hasStates && (_state == null || _state!.trim().isEmpty)) {
      setState(() => _error = 'Please select your state / province');
      return;
    }
    if (_city == null || _city!.trim().isEmpty) {
      setState(() => _error = 'Please select your city');
      return;
    }
    final needsFamilyDetails = needsFamilyDetailsStatuses.contains(_maritalStatus);
    if (needsFamilyDetails && _hasChildren == null) {
      setState(() => _error = 'Please let us know if you have children');
      return;
    }
    if (needsFamilyDetails && (_livingSituation == null || _livingSituation!.isEmpty)) {
      setState(() => _error = 'Please let us know who you currently live with');
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
        'date_of_birth':
            '${_dateOfBirth!.year.toString().padLeft(4, '0')}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}',
        'height': _height,
        'height_other': _height == 'Other'
            ? _heightOtherController.text.trim()
            : null,
        'marital_status': _maritalStatus,
        if (needsFamilyDetails) 'has_children': _hasChildren,
        if (needsFamilyDetails && _hasChildren == true)
          'children_count': int.tryParse(_childrenCountController.text.trim()),
        if (needsFamilyDetails) 'living_situation': _livingSituation,
        'city': _city,
        'address': _addressController.text.trim(),
        'state': _state,
        'country': _country,
        'guardian_name': _guardianNameController.text.trim(),
        'guardian_contact': _guardianContactController.text.trim(),
        'guardian_relation': _guardianRelation == 'Other'
            ? _guardianRelationOtherController.text.trim()
            : _guardianRelation,
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
      builder: (context) => _SearchablePicker(
        title: 'Select Country',
        options: allCountries,
        initialValue: _country,
      ),
    );
    if (selected != null) {
      setState(() {
        _country = selected;
        _state = null;
        _city = null;
      });
    }
  }

  // Unlike Country (preloaded, ~250 entries), City is a live-search combo
  // backed by the ~150k-row cities table — see CitySearchRepository and
  // _AsyncSearchablePicker below.
  Future<void> _pickCity() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AsyncSearchablePicker(
        title: 'Select City',
        search: (query) => ref
            .read(citySearchRepositoryProvider)
            .search(query: query, country: _country, state: _state),
      ),
    );
    if (selected != null) setState(() => _city = selected);
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
      actions: const [WhatsappChannelAction()],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tell us about yourself',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _GenderPicker(
              value: _gender,
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDateOfBirth,
              child: InputDecorator(
                decoration: InputDecoration(
                  label: requiredLabel('Date of Birth'),
                ),
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
              decoration: InputDecoration(label: requiredLabel('Height')),
              items: _heightOptions()
                  .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                  .toList(),
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
              decoration: InputDecoration(
                label: requiredLabel('Marital Status'),
              ),
              items: maritalStatusOptions.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _maritalStatus = v!;
                if (!needsFamilyDetailsStatuses.contains(v)) {
                  _hasChildren = null;
                  _livingSituation = null;
                  _childrenCountController.clear();
                }
              }),
            ),
            if (needsFamilyDetailsStatuses.contains(_maritalStatus)) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<bool>(
                initialValue: _hasChildren,
                decoration: InputDecoration(label: requiredLabel('Do You Have Children?')),
                items: const [
                  DropdownMenuItem(value: true, child: Text('Yes')),
                  DropdownMenuItem(value: false, child: Text('No')),
                ],
                onChanged: (v) => setState(() => _hasChildren = v),
              ),
              if (_hasChildren == true) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _childrenCountController,
                  decoration: const InputDecoration(labelText: 'Number of Children'),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _livingSituation,
                decoration: InputDecoration(label: requiredLabel('Who Do You Currently Live With?')),
                isExpanded: true,
                items: _livingSituationOptions.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _livingSituation = v),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            countryStatesAsync.when(
              data: (cs) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => _pickCountry(cs.countries),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        label: requiredLabel('Country'),
                      ),
                      child: Text(_country),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (cs.statesFor(_country).isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: _state,
                      decoration: InputDecoration(
                        label: requiredLabel('State / Province'),
                      ),
                      items: cs
                          .statesFor(_country)
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _state = v),
                    ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
              error: (error, stack) => TextFormField(
                initialValue: _country,
                decoration: InputDecoration(label: requiredLabel('Country')),
                onChanged: (v) => _country = v,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickCity,
              child: InputDecorator(
                decoration: InputDecoration(label: requiredLabel('City')),
                child: Text(_city ?? 'Select city'),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Guardian (Wali)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Required for Nikah profiles — your guardian is your point of contact for serious matches.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _guardianNameController,
              decoration: InputDecoration(
                label: requiredLabel('Guardian Name (Sarparast Family)'),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _guardianContactController,
              decoration: InputDecoration(
                label: requiredLabel(
                  'Guardian Phone Number (Sarparast Family)',
                ),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _guardianRelation,
              decoration: const InputDecoration(labelText: 'Relation'),
              items: _guardianRelationOptions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
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
        Expanded(
          child: _GenderTile(
            label: 'Male',
            emoji: '👨',
            selected: value == 'male',
            onTap: () => onChanged('male'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GenderTile(
            label: 'Female',
            emoji: '👩',
            selected: value == 'female',
            onTap: () => onChanged('female'),
          ),
        ),
      ],
    );
  }
}

class _GenderTile extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  const _GenderTile({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

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
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? color : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// City's picker — same sheet feel as _SearchablePicker below, but the
// options list comes from a debounced API call (CitySearchRepository)
// instead of filtering an in-memory list, since cities can't be preloaded.
// Includes a "Use <typed text>" row so a real city missing from our ~150k
// rows can still be entered, same pick-or-type leniency the backend
// validation (and the web's equivalent combo) already allows.
class _AsyncSearchablePicker extends StatefulWidget {
  final String title;
  final Future<List<String>> Function(String query) search;
  const _AsyncSearchablePicker({required this.title, required this.search});

  @override
  State<_AsyncSearchablePicker> createState() => _AsyncSearchablePickerState();
}

class _AsyncSearchablePickerState extends State<_AsyncSearchablePicker> {
  final _searchController = TextEditingController();
  List<String> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _loading = true);
      try {
        final results = await widget.search(query);
        if (mounted) setState(() => _results = results);
      } catch (_) {
        if (mounted) setState(() => _results = []);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final exactMatch = _results.any(
      (r) => r.toLowerCase() == query.toLowerCase(),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (v) {
                  setState(() {});
                  _onSearchChanged(v);
                },
                decoration: InputDecoration(
                  hintText: 'Search…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
                autofocus: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  if (query.isNotEmpty && !exactMatch)
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: Text('Use "$query"'),
                      onTap: () => Navigator.of(context).pop(query),
                    ),
                  ..._results.map(
                    (option) => ListTile(
                      title: Text(option),
                      onTap: () => Navigator.of(context).pop(option),
                    ),
                  ),
                ],
              ),
            ),
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
  const _SearchablePicker({
    required this.title,
    required this.options,
    this.initialValue,
  });

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
          : widget.options
                .where((o) => o.toLowerCase().contains(query.toLowerCase()))
                .toList();
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
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Search…',
                  prefixIcon: Icon(Icons.search),
                ),
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
