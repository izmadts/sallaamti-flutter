import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../data/counseling_repository.dart';
import 'counseling_bookings_screen.dart';

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
      await _loadSlots();
    } on ApiException catch (e) {
      setState(() => _metaError = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _metaError = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _selectedSlot = null;
    });
    try {
      final slots = await ref.read(counselingRepositoryProvider).slots(
            date: _date,
            counselorIds: _counselorId != null ? [_counselorId!] : null,
          );
      setState(() {
        _slots = slots;
        _noAvailability = slots.where((s) => !s.booked).isEmpty;
      });
    } catch (_) {
      setState(() {
        _slots = [];
        _noAvailability = true;
      });
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

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
    if (time == null) return;

    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _preferredAt = combined;
      _preferredTimeController.text = '${combined.day}/${combined.month}/${combined.year} at ${time.format(context)}';
    });
  }

  Future<void> _submit() async {
    if (_category == null || _contactMethod == null) return;
    if (_subjectController.text.trim().isEmpty) {
      setState(() => _submitError = 'Please enter a subject.');
      return;
    }
    if (_descriptionController.text.trim().length < 20) {
      setState(() => _submitError = 'Please describe your situation in at least 20 characters.');
      return;
    }
    if (_noAvailability && _preferredAt == null) {
      setState(() => _submitError = 'Please choose a preferred date and time.');
      return;
    }
    if (!_noAvailability && _selectedSlot == null) {
      setState(() => _submitError = 'Please choose a time slot.');
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
            counselorId: _noAvailability ? null : _selectedSlot!.counselorId,
            scheduledAt: _noAvailability ? null : _selectedSlot!.dateTime,
            preferredAt: _noAvailability ? _preferredAt : null,
          );
      setState(() => _submitted = true);
    } on ApiException catch (e) {
      setState(() => _submitError = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _submitError = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('counseling'),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Family Counseling'),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'My Sessions',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CounselingBookingsScreen())),
            ),
          ],
        ),
        body: SafeArea(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
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
              ElevatedButton(onPressed: _loadMeta, child: const Text('Retry')),
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
              const Text('Session Requested!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Your counselor will confirm shortly, in sha Allah. You can track it under My Sessions.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const CounselingBookingsScreen())),
                child: const Text('View My Sessions'),
              ),
              TextButton(onPressed: () => context.go('/dashboard'), child: const Text('Back to Dashboard')),
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
          const Text('Book a Counseling Session', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(
            'A free, confidential session with one of our counselors.',
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
            decoration: const InputDecoration(labelText: 'What is this about?'),
            items: meta.categories.map((c) => DropdownMenuItem(value: c, child: Text(counselingCategories[c] ?? c))).toList(),
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _subjectController,
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Tell us a bit more about your situation'),
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Keep this anonymous from the counselor'),
            value: _isAnonymous,
            onChanged: (v) => setState(() => _isAnonymous = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('This is urgent'),
            value: _isUrgent,
            onChanged: (v) => setState(() => _isUrgent = v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _contactMethod,
            decoration: const InputDecoration(labelText: 'Preferred Contact Method'),
            items: meta.contactMethods.map((c) => DropdownMenuItem(value: c, child: Text(counselingContactMethods[c] ?? c))).toList(),
            onChanged: (v) => setState(() => _contactMethod = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            initialValue: _counselorId,
            decoration: const InputDecoration(labelText: 'Counselor'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Any Available')),
              ...meta.counselors.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
            ],
            onChanged: (v) {
              setState(() => _counselorId = v);
              _loadSlots();
            },
          ),
          const SizedBox(height: 20),
          const Text('Choose a Time', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text('${_date.day}/${_date.month}/${_date.year}'),
          ),
          const SizedBox(height: 12),
          if (_loadingSlots)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_noAvailability)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    'No open slots right now — let us know your preferred date and time and a counselor will follow up to confirm.',
                    style: TextStyle(color: Colors.deepOrange),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickPreferredDateTime,
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(_preferredTimeController.text.isEmpty ? 'Pick a preferred date & time' : _preferredTimeController.text),
                ),
              ],
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _slots.map((slot) {
                final time = '${slot.dateTime.hour.toString().padLeft(2, '0')}:${slot.dateTime.minute.toString().padLeft(2, '0')}'
                    '${_counselorId == null ? ' · ${slot.counselorName ?? ''}' : ''}';

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
            if (_counselorId != null && _slots.any((s) => s.booked)) ...[
              const SizedBox(height: 8),
              Text('Greyed-out times are already booked.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Request Session'),
          ),
        ],
      ),
    );
  }
}
