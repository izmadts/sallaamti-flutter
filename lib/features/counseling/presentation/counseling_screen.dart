import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/counseling_repository.dart';
import 'counseling_bookings_screen.dart';

String counselingCategoryLabel(AppLocalizations l10n, String? value) => {
      'marital': l10n.counselingCategoryMarital,
      'parenting': l10n.counselingCategoryParenting,
      'financial': l10n.counselingCategoryFinancial,
      'legal': l10n.counselingCategoryLegal,
      'spiritual': l10n.counselingCategorySpiritual,
      'other': l10n.counselingCategoryOther,
    }[value] ?? (value ?? '');

String counselingContactMethodLabel(AppLocalizations l10n, String? value) => {
      'phone': l10n.counselingContactPhone,
      'video': l10n.counselingContactVideo,
      'in_person': l10n.counselingContactInPerson,
      'chat': l10n.counselingContactChat,
    }[value] ?? (value ?? '');

String counselingStatusLabel(AppLocalizations l10n, String status) => {
      'confirmed': l10n.counselingStatusConfirmed,
      'completed': l10n.counselingStatusCompleted,
      'cancelled': l10n.counselingStatusCancelled,
      'no_show': l10n.counselingStatusNoShow,
    }[status] ?? l10n.counselingStatusRequested;

class CounselingScreen extends ConsumerStatefulWidget {
  const CounselingScreen({super.key});

  @override
  ConsumerState<CounselingScreen> createState() => _CounselingScreenState();
}

class _CounselingScreenState extends ConsumerState<CounselingScreen> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  CounselingMeta? _meta;
  bool _loadingMeta = true;
  String? _metaError;

  String? _category;
  bool _isAnonymous = false;
  bool _isUrgent = false;
  String? _contactMethod;
  int? _counselorId; // null = "Any Available"
  DateTime _date = DateTime.now();

  List<CounselingSlot> _slots = [];
  bool _loadingSlots = false;
  CounselingSlot? _selectedSlot;
  bool _noAvailability = false;
  String? _slotsError;
  final _preferredTimeController = TextEditingController();
  DateTime? _preferredAt;

  bool _submitting = false;
  bool _submitted = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _preferredTimeController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loadingMeta = true;
      _metaError = null;
    });
    try {
      final meta = await ref.read(counselingRepositoryProvider).meta();
      setState(() {
        _meta = meta;
        if (meta.categories.isNotEmpty) _category = meta.categories.first;
        if (meta.contactMethods.isNotEmpty) _contactMethod = meta.contactMethods.first;
      });
      // "Any Available" (the default) skips the slot grid entirely — see
      // _loadSlots()'s own comment.
      if (_counselorId != null) await _loadSlots();
    } on ApiException catch (e) {
      setState(() => _metaError = e.displayMessage);
    } catch (_) {
      // Called from initState() — looked up after the await above rather
      // than hoisted, since Localizations isn't registered yet that early.
      if (mounted) setState(() => _metaError = AppLocalizations.of(context)!.errorGeneric);
    } finally {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  // Only called when a specific counselor is selected — "Any Available"
  // means no one particular schedule applies, so rather than aggregate
  // (and potentially misrepresent) multiple counselors' slots together,
  // the member just states a preferred date/time and a counselor follows
  // up to confirm, same as the "fully booked" fallback below.
  Future<void> _loadSlots() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loadingSlots = true;
      _selectedSlot = null;
      _slotsError = null;
    });
    try {
      final slots = await ref.read(counselingRepositoryProvider).slots(
            date: _date,
            counselorIds: _counselorId != null ? [_counselorId!] : null,
          );
      setState(() {
        _slots = slots;
        // Empty means no schedule at all for this day - distinct from
        // "has a schedule but every slot is already booked", which still
        // needs the grid rendered (see _hasOpenSlot) so the member can see
        // why, not just a generic "no availability" message.
        _noAvailability = slots.isEmpty;
      });
    } on ApiException catch (e) {
      setState(() {
        _slots = [];
        _noAvailability = true;
        _slotsError = e.displayMessage;
      });
    } catch (_) {
      setState(() {
        _slots = [];
        _noAvailability = true;
        _slotsError = l10n.counselingLoadSlotsError;
      });
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  bool get _hasOpenSlot => _slots.any((s) => !s.booked);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _loadSlots();
    }
  }

  Future<void> _pickPreferredDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null || !mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _preferredAt = combined;
      _preferredTimeController.text = l10n.dateAtTimeLabel('${combined.day}/${combined.month}/${combined.year}', time.format(context));
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_category == null || _contactMethod == null) return;
    if (_subjectController.text.trim().isEmpty) {
      setState(() => _submitError = l10n.counselingSubjectRequiredError);
      return;
    }
    if (_descriptionController.text.trim().length < 20) {
      setState(() => _submitError = l10n.counselingDescriptionTooShortError);
      return;
    }
    if (!_hasOpenSlot && _preferredAt == null) {
      setState(() => _submitError = l10n.counselingChoosePreferredTimeError);
      return;
    }
    if (_hasOpenSlot && _selectedSlot == null) {
      setState(() => _submitError = l10n.counselingChooseSlotError);
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      await ref.read(counselingRepositoryProvider).createBooking(
            category: _category!,
            subject: _subjectController.text.trim(),
            description: _descriptionController.text.trim(),
            isAnonymous: _isAnonymous,
            isUrgent: _isUrgent,
            contactMethod: _contactMethod!,
            counselorId: _hasOpenSlot ? _selectedSlot!.counselorId : null,
            scheduledAt: _hasOpenSlot ? _selectedSlot!.dateTime : null,
            preferredAt: _hasOpenSlot ? null : _preferredAt,
          );
      setState(() => _submitted = true);
    } on ApiException catch (e) {
      setState(() => _submitError = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _submitError = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Theme(
      data: ModuleThemes.forModule('counseling'),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.familyCounselingTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: l10n.mySessionsLabel,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CounselingBookingsScreen())),
            ),
          ],
        ),
        body: SafeArea(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loadingMeta) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_metaError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_metaError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadMeta, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }

    if (_submitted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🤝', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(l10n.counselingSessionRequestedTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                l10n.counselingSessionRequestedMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const CounselingBookingsScreen())),
                child: Text(l10n.viewMySessionsButton),
              ),
              TextButton(onPressed: () => context.go('/dashboard'), child: Text(l10n.backToDashboardButton)),
            ],
          ),
        ),
      );
    }

    final meta = _meta!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('🤝', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(l10n.bookCounselingSessionTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(
            l10n.counselingFreeConfidentialMessage,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          if (_submitError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
              child: Text(_submitError!, style: TextStyle(color: Colors.red.shade700)),
            ),
            const SizedBox(height: 16),
          ],
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(labelText: l10n.whatIsThisAboutLabel),
            items: meta.categories.map((c) => DropdownMenuItem(value: c, child: Text(counselingCategoryLabel(l10n, c)))).toList(),
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _subjectController,
            decoration: InputDecoration(labelText: l10n.subjectLabel),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: l10n.tellUsMoreHint),
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.keepAnonymousFromCounselorLabel),
            value: _isAnonymous,
            onChanged: (v) => setState(() => _isAnonymous = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.thisIsUrgentLabel),
            value: _isUrgent,
            onChanged: (v) => setState(() => _isUrgent = v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _contactMethod,
            decoration: InputDecoration(labelText: l10n.preferredContactMethodLabel),
            items: meta.contactMethods.map((c) => DropdownMenuItem(value: c, child: Text(counselingContactMethodLabel(l10n, c)))).toList(),
            onChanged: (v) => setState(() => _contactMethod = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            initialValue: _counselorId,
            decoration: InputDecoration(labelText: l10n.counselorLabel),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.anyAvailableLabel)),
              ...meta.counselors.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
            ],
            onChanged: (v) {
              setState(() {
                _counselorId = v;
                _selectedSlot = null;
                _slots = [];
                _noAvailability = false;
                _slotsError = null;
              });
              if (v != null) _loadSlots();
            },
          ),
          const SizedBox(height: 20),
          Text(l10n.chooseATimeLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (_counselorId == null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12)),
              child: Text(
                l10n.counselingAnyCounselorMessage,
                style: const TextStyle(color: Colors.teal),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickPreferredDateTime,
              icon: const Icon(Icons.access_time, size: 16),
              label: Text(_preferredTimeController.text.isEmpty ? l10n.pickPreferredDateTimeButton : _preferredTimeController.text),
            ),
          ] else ...[
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text('${_date.day}/${_date.month}/${_date.year}'),
          ),
          const SizedBox(height: 12),
          if (_loadingSlots)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_slotsError != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Text(_slotsError!, style: TextStyle(color: Colors.red.shade700)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loadSlots,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(l10n.retry),
                ),
              ],
            )
          else if (_noAvailability)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    l10n.counselingNoOpenSlotsMessage,
                    style: const TextStyle(color: Colors.deepOrange),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickPreferredDateTime,
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(_preferredTimeController.text.isEmpty ? l10n.pickPreferredDateTimeButton : _preferredTimeController.text),
                ),
              ],
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _slots.map((slot) {
                final time = '${slot.dateTime.hour.toString().padLeft(2, '0')}:${slot.dateTime.minute.toString().padLeft(2, '0')}';

                if (slot.booked) {
                  return Chip(
                    label: Text(time, style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey.shade400)),
                    avatar: Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400),
                    backgroundColor: Colors.grey.shade100,
                    side: BorderSide(color: Colors.grey.shade300),
                  );
                }

                return ChoiceChip(
                  label: Text(time),
                  selected: _selectedSlot == slot,
                  onSelected: (_) => setState(() => _selectedSlot = slot),
                );
              }).toList(),
            ),
            if (_slots.any((s) => s.booked)) ...[
              const SizedBox(height: 8),
              Text(l10n.counselingGreyedOutBookedMessage, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
            if (!_hasOpenSlot) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  l10n.counselingFullyBookedMessage,
                  style: const TextStyle(color: Colors.deepOrange),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickPreferredDateTime,
                icon: const Icon(Icons.access_time, size: 16),
                label: Text(_preferredTimeController.text.isEmpty ? l10n.pickPreferredDateTimeButton : _preferredTimeController.text),
              ),
            ],
          ],
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(l10n.requestSessionButton),
          ),
        ],
      ),
    );
  }
}
