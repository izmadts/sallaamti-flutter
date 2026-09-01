import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/data/country_states_repository.dart';
import '../../../core/theme/module_themes.dart';
import '../../../shared/widgets/required_label.dart';
import '../../../shared/widgets/step_wizard_scaffold.dart';
import '../data/quran_live_repository.dart';

// Mirrors the web's 3-step admission wizard (QuranLiveCourseController) but
// as one screen with local step state instead of a session-persisted
// server round-trip per step — same "mobile collapses the web wizard"
// tradeoff CounselingController's mobile side already made. The whole
// admission only actually posts once, on the final step.
class QuranLiveAdmissionScreen extends ConsumerStatefulWidget {
  final int courseId;
  const QuranLiveAdmissionScreen({super.key, required this.courseId});

  @override
  ConsumerState<QuranLiveAdmissionScreen> createState() => _QuranLiveAdmissionScreenState();
}

class _QuranLiveAdmissionScreenState extends ConsumerState<QuranLiveAdmissionScreen> {
  late Future<(QuranLiveMeta, QuranLiveCourseInfo)> _initFuture;
  // Mirrored out of _initFuture once it resolves so _advance() (a plain
  // sync method, not itself future-aware) can check the course's own
  // age/gender restriction before letting the student step proceed.
  QuranLiveCourseInfo? _course;

  int _step = 0;
  bool _busy = false;
  String? _error;

  final _guardianNameController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _cityStateController = TextEditingController();
  String _country = 'Pakistan';

  final _studentNameController = TextEditingController();
  String? _studentGender;
  final _studentAgeController = TextEditingController();
  String? _educationGrade;
  bool _learnedQuranBefore = false;

  final _daysSelected = <String>{};
  String? _preferredTime;
  String _timezone = 'Asia/Karachi';
  String _teacherPreference = 'no_preference';
  String? _selectedLevel;
  String? _previousLevel;
  String _classType = 'group';
  final _commentsController = TextEditingController();
  bool _declarationAccepted = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _loadInit();
  }

  Future<(QuranLiveMeta, QuranLiveCourseInfo)> _loadInit() async {
    final repository = ref.read(quranLiveRepositoryProvider);
    final results = await Future.wait([repository.meta(), repository.courseDetail(widget.courseId)]);

    final meta = results[0] as QuranLiveMeta;
    final (course, _) = results[1] as (QuranLiveCourseInfo, List<QuranLiveAdmissionInfo>);
    _course = course;

    return (meta, course);
  }

  @override
  void dispose() {
    _guardianNameController.dispose();
    _whatsappController.dispose();
    _cityStateController.dispose();
    _studentNameController.dispose();
    _studentAgeController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  void _advance() {
    setState(() => _error = null);

    if (_step == 0) {
      if (_guardianNameController.text.trim().isEmpty || _whatsappController.text.trim().isEmpty) {
        setState(() => _error = 'Please fill in the guardian name and WhatsApp number.');
        return;
      }
    } else if (_step == 1) {
      if (_studentNameController.text.trim().isEmpty || _studentGender == null || _studentAgeController.text.trim().isEmpty) {
        setState(() => _error = 'Please fill in the student\'s name, gender, and age.');
        return;
      }

      // Checked here (client-side, before the round trip) as well as
      // server-side (QuranLiveController::admissionRules' ageRule/genderRule)
      // — catching it now saves a submit-and-fail on the very last step.
      final course = _course;
      final age = int.tryParse(_studentAgeController.text.trim());
      if (course != null && age != null) {
        if (course.minAge != null && age < course.minAge!) {
          setState(() => _error = 'This class is for ages ${course.minAge}${course.maxAge != null ? '–${course.maxAge}' : '+'}.');
          return;
        }
        if (course.maxAge != null && age > course.maxAge!) {
          setState(() => _error = 'This class is for ages ${course.minAge ?? 1}–${course.maxAge}.');
          return;
        }
        if (course.genderPreference != null && course.genderPreference != 'both' && _studentGender != course.genderPreference) {
          setState(() => _error = 'This class is for ${course.genderPreference} students only.');
          return;
        }
      }
    }

    setState(() => _step += 1);
  }

  Future<void> _next() async {
    if (_step < 2) {
      _advance();
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    if (!_declarationAccepted) {
      setState(() => _error = 'Please confirm the declaration to continue.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final admission = await ref.read(quranLiveRepositoryProvider).storeAdmission(
            courseId: widget.courseId,
            guardianName: _guardianNameController.text.trim(),
            whatsappNumber: _whatsappController.text.trim(),
            country: _country,
            cityState: _cityStateController.text.trim().isEmpty ? null : _cityStateController.text.trim(),
            studentName: _studentNameController.text.trim(),
            studentGender: _studentGender!,
            studentAge: int.parse(_studentAgeController.text.trim()),
            educationGrade: _educationGrade,
            learnedQuranBefore: _learnedQuranBefore,
            preferredDays: _daysSelected.toList(),
            preferredTime: _preferredTime,
            teacherPreference: _teacherPreference,
            comments: _commentsController.text.trim().isEmpty ? null : _commentsController.text.trim(),
            selectedLevel: _selectedLevel,
            previousLevel: _previousLevel,
            classType: _classType,
            timezone: _timezone,
          );
      if (mounted) {
        context.pushReplacement('/quran-live/${widget.courseId}/subscribe/${admission.id}');
      }
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('quran_live'),
      child: FutureBuilder<(QuranLiveMeta, QuranLiveCourseInfo)>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException ? (snapshot.error as ApiException).displayMessage : 'Something went wrong.';
            return Scaffold(
              appBar: AppBar(title: const Text('Admission')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(message, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: () => setState(() => _initFuture = _loadInit()), child: const Text('Retry')),
                    ],
                  ),
                ),
              ),
            );
          }

          final (meta, course) = snapshot.data!;
          return StepWizardScaffold(
            title: 'Admission',
            stepIndex: _step,
            totalSteps: 3,
            nextLabel: _step < 2 ? 'Next' : 'Submit Admission',
            onNext: _next,
            onBack: () => _step == 0 ? Navigator.of(context).pop() : setState(() => _step -= 1),
            busy: _busy,
            errorText: _error,
            child: switch (_step) {
              0 => _ParentStep(
                  guardianNameController: _guardianNameController,
                  whatsappController: _whatsappController,
                  cityStateController: _cityStateController,
                  country: _country,
                  onCountryChanged: (v) => setState(() => _country = v),
                ),
              1 => _StudentStep(
                  course: course,
                  studentNameController: _studentNameController,
                  studentAgeController: _studentAgeController,
                  studentGender: _studentGender,
                  onGenderChanged: (v) => setState(() => _studentGender = v),
                  educationGrade: _educationGrade,
                  grades: meta.grades,
                  onGradeChanged: (v) => setState(() => _educationGrade = v),
                  learnedQuranBefore: _learnedQuranBefore,
                  onLearnedChanged: (v) => setState(() => _learnedQuranBefore = v),
                ),
              _ => _PreferencesStep(
                  meta: meta,
                  daysSelected: _daysSelected,
                  onDayToggled: (day, selected) => setState(() => selected ? _daysSelected.add(day) : _daysSelected.remove(day)),
                  preferredTime: _preferredTime,
                  onPreferredTimeChanged: (v) => setState(() => _preferredTime = v),
                  timezone: _timezone,
                  onTimezoneChanged: (v) => setState(() => _timezone = v),
                  teacherPreference: _teacherPreference,
                  onTeacherPreferenceChanged: (v) => setState(() => _teacherPreference = v!),
                  selectedLevel: _selectedLevel,
                  onSelectedLevelChanged: (v) => setState(() => _selectedLevel = v),
                  previousLevel: _previousLevel,
                  onPreviousLevelChanged: (v) => setState(() => _previousLevel = v),
                  classType: _classType,
                  onClassTypeChanged: (v) => setState(() => _classType = v!),
                  commentsController: _commentsController,
                  declarationAccepted: _declarationAccepted,
                  onDeclarationChanged: (v) => setState(() => _declarationAccepted = v),
                ),
            },
          );
        },
      ),
    );
  }
}

class _ParentStep extends ConsumerWidget {
  final TextEditingController guardianNameController;
  final TextEditingController whatsappController;
  final TextEditingController cityStateController;
  final String country;
  final ValueChanged<String> onCountryChanged;

  const _ParentStep({
    required this.guardianNameController,
    required this.whatsappController,
    required this.cityStateController,
    required this.country,
    required this.onCountryChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countryStatesAsync = ref.watch(countryStatesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Parent & Contact', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Who should we reach out to about this admission?', style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 20),
        TextFormField(
          controller: guardianNameController,
          decoration: InputDecoration(label: requiredLabel('Parent / Guardian Full Name')),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: whatsappController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(label: requiredLabel('WhatsApp Number (with country code)'), hintText: '+92 3XX XXXXXXX'),
        ),
        const SizedBox(height: 16),
        countryStatesAsync.when(
          data: (cs) => DropdownButtonFormField<String>(
            initialValue: cs.countries.contains(country) ? country : null,
            isExpanded: true,
            decoration: InputDecoration(label: requiredLabel('Country')),
            items: cs.countries.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) {
              if (v != null) onCountryChanged(v);
            },
          ),
          loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()),
          error: (error, stack) => TextFormField(
            initialValue: country,
            decoration: InputDecoration(label: requiredLabel('Country')),
            onChanged: onCountryChanged,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: cityStateController,
          decoration: const InputDecoration(labelText: 'City / State'),
        ),
      ],
    );
  }
}

class _StudentStep extends StatelessWidget {
  final QuranLiveCourseInfo course;
  final TextEditingController studentNameController;
  final TextEditingController studentAgeController;
  final String? studentGender;
  final ValueChanged<String> onGenderChanged;
  final String? educationGrade;
  final List<String> grades;
  final ValueChanged<String?> onGradeChanged;
  final bool learnedQuranBefore;
  final ValueChanged<bool> onLearnedChanged;

  const _StudentStep({
    required this.course,
    required this.studentNameController,
    required this.studentAgeController,
    required this.studentGender,
    required this.onGenderChanged,
    required this.educationGrade,
    required this.grades,
    required this.onGradeChanged,
    required this.learnedQuranBefore,
    required this.onLearnedChanged,
  });

  bool get _hasRestriction =>
      course.minAge != null || course.maxAge != null || (course.genderPreference != null && course.genderPreference != 'both');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('About the Student', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          'Admitting more than one child? Use each child\'s own name — that\'s what tells them apart.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
        ),
        // Shown up front so a family finds out before filling in every
        // field, not after tapping Submit on the last step.
        if (_hasRestriction) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFE0F2F1), borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ℹ️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [
                      if (course.minAge != null || course.maxAge != null)
                        'Ages ${course.minAge ?? 0}${course.maxAge != null ? '–${course.maxAge}' : '+'}',
                      if (course.genderPreference == 'male') 'boys only',
                      if (course.genderPreference == 'female') 'girls only',
                    ].join(', '),
                    style: const TextStyle(color: Color(0xFF0D6B6B), fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        TextFormField(
          controller: studentNameController,
          decoration: InputDecoration(label: requiredLabel('Student Full Name')),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: studentGender,
                isExpanded: true,
                decoration: InputDecoration(label: requiredLabel('Gender')),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                ],
                onChanged: (v) {
                  if (v != null) onGenderChanged(v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: studentAgeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(label: requiredLabel('Age')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: educationGrade,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Current Education Grade (optional)'),
          items: grades.map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onGradeChanged,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Student has learned Quran before'),
          value: learnedQuranBefore,
          onChanged: onLearnedChanged,
        ),
      ],
    );
  }
}

class _PreferencesStep extends StatelessWidget {
  final QuranLiveMeta meta;
  final Set<String> daysSelected;
  final void Function(String day, bool selected) onDayToggled;
  final String? preferredTime;
  final ValueChanged<String?> onPreferredTimeChanged;
  final String timezone;
  final ValueChanged<String> onTimezoneChanged;
  final String teacherPreference;
  final ValueChanged<String?> onTeacherPreferenceChanged;
  final String? selectedLevel;
  final ValueChanged<String?> onSelectedLevelChanged;
  final String? previousLevel;
  final ValueChanged<String?> onPreviousLevelChanged;
  final String classType;
  final ValueChanged<String?> onClassTypeChanged;
  final TextEditingController commentsController;
  final bool declarationAccepted;
  final ValueChanged<bool> onDeclarationChanged;

  const _PreferencesStep({
    required this.meta,
    required this.daysSelected,
    required this.onDayToggled,
    required this.preferredTime,
    required this.onPreferredTimeChanged,
    required this.timezone,
    required this.onTimezoneChanged,
    required this.teacherPreference,
    required this.onTeacherPreferenceChanged,
    required this.selectedLevel,
    required this.onSelectedLevelChanged,
    required this.previousLevel,
    required this.onPreviousLevelChanged,
    required this.classType,
    required this.onClassTypeChanged,
    required this.commentsController,
    required this.declarationAccepted,
    required this.onDeclarationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Class Preferences', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        const Text('Preferred Class Days', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: meta.days.map((day) {
            final selected = daysSelected.contains(day);
            return FilterChip(label: Text(day), selected: selected, onSelected: (v) => onDayToggled(day, v));
          }).toList(),
        ),
        const SizedBox(height: 16),
        const Text('Preferred Time', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 2),
        Text("Our academy's available class slots, shown in Pakistan Time (PKT).", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: preferredTime,
          isExpanded: true,
          decoration: const InputDecoration(),
          items: meta.times.map((t) => DropdownMenuItem(value: t, child: Text('$t PKT', overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onPreferredTimeChanged,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: meta.timezones.contains(timezone) ? timezone : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Your Timezone'),
          items: meta.timezones.map((tz) => DropdownMenuItem(value: tz, child: Text(tz, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) {
            if (v != null) onTimezoneChanged(v);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: teacherPreference,
          isExpanded: true,
          decoration: InputDecoration(label: requiredLabel('Teacher Preference')),
          items: meta.teacherPreferences.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onTeacherPreferenceChanged,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: selectedLevel,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Which Level are you applying for?'),
          items: meta.levels
              .map((l) => DropdownMenuItem(value: l.title, child: Text(l.levelNumber != null ? '${l.levelNumber} — ${l.title}' : l.title, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: onSelectedLevelChanged,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: previousLevel,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Previous Level Completed (if any)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('None / First time')),
            ...meta.levels.map((l) => DropdownMenuItem(
                value: l.title, child: Text(l.levelNumber != null ? '${l.levelNumber} — ${l.title}' : l.title, overflow: TextOverflow.ellipsis))),
          ],
          onChanged: onPreviousLevelChanged,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: classType,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Class Type Preference'),
          items: meta.classTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onClassTypeChanged,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: commentsController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Special Requirements / Comments (optional)'),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: declarationAccepted,
          onChanged: (v) => onDeclarationChanged(v ?? false),
          title: const Text(
            'I confirm the information above is accurate and I agree to Sallaamti\'s Quran Live class terms.',
            style: TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
