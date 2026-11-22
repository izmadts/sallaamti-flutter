import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'dart:async';

import '../../../../core/api/api_exception.dart';
import '../../../../core/data/city_search_repository.dart';
import '../../../../core/data/country_states_repository.dart';
import '../../../../core/theme/module_themes.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/async_searchable_picker.dart';
import '../../../../shared/widgets/required_label.dart';
import '../../../../shared/widgets/step_wizard_scaffold.dart';
import '../../domain/nikah_labels.dart';
import '../../domain/nikah_profile.dart';
import '../../state/nikah_controller.dart';

// Heights 4'0" to 7'0", matching the height-range filter the browse
// endpoint already supports on the backend. The stored value is the raw
// measurement string itself (or the literal "Other") — translating only
// ever happens at display time (see the 'Other' DropdownMenuItem below),
// never to this list, since these values round-trip straight to the API.
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

// Matches ValidatesNikahProfile's required_if list on the backend — these
// three fields were missing from the mobile wizard entirely (never shown,
// never sent), so a divorced/widowed/separated/married member could finish
// on mobile with none of this recorded, unlike web. Public (no leading
// underscore) — nikah_home_screen.dart reuses it to decide whether these
// fields count toward "is this profile actually finished".
const needsFamilyDetailsStatuses = ['divorced', 'widowed', 'separated', 'married'];

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
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    // Found live (16 Nov 2026): nikahControllerProvider fetches the profile
    // asynchronously (NikahController's constructor calls refresh()) — on a
    // cold app start, a slow connection, or a deep link straight into Edit
    // Profile, this ran before that fetch finished, saw profile == null,
    // and gave up for good (initState only ever runs once). Every field
    // below — including Date of Birth — then stayed blank for the rest of
    // the screen's life, and an unsuspecting save() could overwrite a
    // member's real saved values with empty ones. build()'s ref.listen
    // below covers the case this misses: profile arriving after mount.
    final profile = ref.read(nikahControllerProvider).profile;
    if (profile == null) return;
    _prefillFrom(profile);
  }

  void _prefillFrom(NikahProfile profile) {
    _prefilled = true;
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
      if (guardianRelationValues.contains(profile.guardianRelation)) {
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
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: l10n.dateOfBirthLabel,
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
      setState(() => _error = l10n.nikahPleaseSelectDob);
      return;
    }
    if (_height == null || _height!.trim().isEmpty) {
      setState(() => _error = l10n.nikahPleaseSelectHeight);
      return;
    }
    // State is only genuinely optional when the picked country has no
    // states/provinces in our data at all — matches the web forms' same
    // "required unless the field can't apply" treatment.
    final hasStates = (ref.read(countryStatesProvider).valueOrNull?.statesFor(_country) ?? []).isNotEmpty;
    if (hasStates && (_state == null || _state!.trim().isEmpty)) {
      setState(() => _error = l10n.nikahPleaseSelectState);
      return;
    }
    if (_city == null || _city!.trim().isEmpty) {
      setState(() => _error = l10n.nikahPleaseSelectCity);
      return;
    }
    final needsFamilyDetails = needsFamilyDetailsStatuses.contains(_maritalStatus);
    if (needsFamilyDetails && _hasChildren == null) {
      setState(() => _error = l10n.nikahPleaseAnswerChildren);
      return;
    }
    if (needsFamilyDetails && (_livingSituation == null || _livingSituation!.isEmpty)) {
      setState(() => _error = l10n.nikahPleaseAnswerLivingSituation);
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
    final l10n = AppLocalizations.of(context)!;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SearchablePicker(
        title: l10n.nikahSelectCountryTitle,
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
  // AsyncSearchablePicker (shared/widgets, also used by Account > Edit
  // Profile's own City field).
  Future<void> _pickCity() async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AsyncSearchablePicker(
        title: l10n.nikahSelectCityTitle,
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

    // Catches the case initState() can't: the profile fetch still in
    // flight when this screen first mounted, resolving some time after.
    // setState() runs synchronously inside the listener here, before this
    // same build() pass's own widgets are laid out, so the fields appear
    // already filled rather than flashing empty for a frame.
    if (!_prefilled) {
      ref.listen(nikahControllerProvider, (previous, next) {
        if (next.profile != null && !_prefilled) {
          setState(() => _prefillFrom(next.profile!));
        }
      });
    }

    return StepWizardScaffold(
      title: l10n.nikahBasicInfoTitle,
      stepIndex: 0,
      totalSteps: 5,
      nextLabel: l10n.nikahNextDeenLifestyle,
      onNext: _next,
      busy: _busy,
      errorText: _error,
      theme: ModuleThemes.forModule('nikah'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.nikahTellUsAboutYourself,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
                  label: requiredLabel(l10n.dateOfBirthLabel),
                ),
                child: Text(
                  _dateOfBirth == null
                      ? l10n.nikahSelectDateLabel
                      : '${_dateOfBirth!.year.toString().padLeft(4, '0')}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _height,
              decoration: InputDecoration(label: requiredLabel(l10n.heightLabel)),
              items: _heightOptions()
                  .map((h) => DropdownMenuItem(value: h, child: Text(h == 'Other' ? l10n.otherLabel : h)))
                  .toList(),
              onChanged: (v) => setState(() => _height = v),
            ),
            if (_height == 'Other') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _heightOtherController,
                decoration: InputDecoration(labelText: l10n.nikahEnterHeightLabel),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _maritalStatus,
              decoration: InputDecoration(
                label: requiredLabel(l10n.maritalStatusLabel),
              ),
              items: maritalStatusOptions(l10n).entries
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
                decoration: InputDecoration(label: requiredLabel(l10n.nikahHaveChildrenLabel)),
                items: [
                  DropdownMenuItem(value: true, child: Text(l10n.yesLabel)),
                  DropdownMenuItem(value: false, child: Text(l10n.noLabel)),
                ],
                onChanged: (v) => setState(() => _hasChildren = v),
              ),
              if (_hasChildren == true) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _childrenCountController,
                  decoration: InputDecoration(labelText: l10n.nikahNumberOfChildrenLabel),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _livingSituation,
                decoration: InputDecoration(label: requiredLabel(l10n.nikahLivingSituationLabel)),
                isExpanded: true,
                items: livingSituationOptions(l10n).entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _livingSituation = v),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              l10n.nikahLocationSectionTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                        label: requiredLabel(l10n.countryLabel),
                      ),
                      child: Text(_country),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (cs.statesFor(_country).isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: _state,
                      decoration: InputDecoration(
                        label: requiredLabel(l10n.stateProvinceLabel),
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
                decoration: InputDecoration(label: requiredLabel(l10n.countryLabel)),
                onChanged: (v) => _country = v,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickCity,
              child: InputDecorator(
                decoration: InputDecoration(label: requiredLabel(l10n.cityLabel)),
                child: Text(_city ?? l10n.nikahSelectCityPlaceholder),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: l10n.nikahAddressOptionalLabel,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.nikahGuardianWaliTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.nikahGuardianRequiredMessage,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _guardianNameController,
              decoration: InputDecoration(
                label: requiredLabel(l10n.nikahGuardianNameLabel),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _guardianContactController,
              decoration: InputDecoration(
                label: requiredLabel(
                  l10n.nikahGuardianPhoneLabel,
                ),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _guardianRelation,
              decoration: InputDecoration(labelText: l10n.relationLabel),
              items: guardianRelationValues
                  .map((r) => DropdownMenuItem(value: r, child: Text(guardianRelationLabel(l10n, r))))
                  .toList(),
              onChanged: (v) => setState(() => _guardianRelation = v),
            ),
            if (_guardianRelation == 'Other') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _guardianRelationOtherController,
                decoration: InputDecoration(labelText: l10n.nikahEnterRelationLabel),
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
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _GenderTile(
            label: l10n.genderMale,
            emoji: '👨',
            selected: value == 'male',
            onTap: () => onChanged('male'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GenderTile(
            label: l10n.genderFemale,
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
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.searchEllipsisHint,
                  prefixIcon: const Icon(Icons.search),
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
