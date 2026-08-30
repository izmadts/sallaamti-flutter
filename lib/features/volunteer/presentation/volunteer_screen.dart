import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../data/volunteer_repository.dart';

const _areaOfInterestOptions = [
  'Teaching',
  'Tech Support',
  'Counseling',
  'Fundraising',
  'Event Support',
  'Administration',
  'Other',
];

class VolunteerScreen extends ConsumerStatefulWidget {
  const VolunteerScreen({super.key});

  @override
  ConsumerState<VolunteerScreen> createState() => _VolunteerScreenState();
}

class _VolunteerScreenState extends ConsumerState<VolunteerScreen> {
  VolunteerApplicationInfo? _application;
  bool _loading = true;
  bool _reapplying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(volunteerRepositoryProvider);
      final application = await repo.status();
      setState(() => _application = application);
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('volunteer'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Volunteer')),
        body: SafeArea(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_application == null || _reapplying) {
      return _VolunteerApplyForm(
        onSubmitted: (application) {
          setState(() {
            _application = application;
            _reapplying = false;
          });
        },
      );
    }

    return _VolunteerStatusView(
      application: _application!,
      onReapply: () => setState(() => _reapplying = true),
    );
  }
}

class _VolunteerApplyForm extends ConsumerStatefulWidget {
  final ValueChanged<VolunteerApplicationInfo> onSubmitted;
  const _VolunteerApplyForm({required this.onSubmitted});

  @override
  ConsumerState<_VolunteerApplyForm> createState() => _VolunteerApplyFormState();
}

class _VolunteerApplyFormState extends ConsumerState<_VolunteerApplyForm> {
  final _cityController = TextEditingController();
  final _messageController = TextEditingController();
  String? _areaOfInterest;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _cityController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(volunteerRepositoryProvider);
      final application = await repo.apply(
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        areaOfInterest: _areaOfInterest,
        message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
      );
      widget.onSubmitted(application);
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('🙌', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Become a Volunteer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Tell us a bit about yourself and how you\'d like to help — our team reviews every application personally.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _cityController,
            decoration: const InputDecoration(labelText: 'City'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _areaOfInterest,
            decoration: const InputDecoration(labelText: 'Area of Interest'),
            items: _areaOfInterestOptions.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
            onChanged: (v) => setState(() => _areaOfInterest = v),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _messageController,
            decoration: const InputDecoration(labelText: 'Anything else you\'d like us to know? (optional)'),
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit Application'),
          ),
        ],
      ),
    );
  }
}

class _VolunteerStatusView extends ConsumerStatefulWidget {
  final VolunteerApplicationInfo application;
  final VoidCallback onReapply;
  const _VolunteerStatusView({required this.application, required this.onReapply});

  @override
  ConsumerState<_VolunteerStatusView> createState() => _VolunteerStatusViewState();
}

class _VolunteerStatusViewState extends ConsumerState<_VolunteerStatusView> {
  bool _downloading = false;
  String? _downloadError;

  Future<void> _downloadIdCard() async {
    setState(() {
      _downloading = true;
      _downloadError = null;
    });
    try {
      final file = await ref.read(volunteerRepositoryProvider).downloadCertificate();
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Sallaamti Volunteer ID'));
    } catch (_) {
      if (mounted) setState(() => _downloadError = 'Could not download your ID card — try again.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final application = widget.application;
    final (emoji, title, subtitle, color) = switch (application.status) {
      'approved' => ('🎉', "You're an approved volunteer!", 'Thank you for stepping up to help — download your ID card below.', Colors.green),
      'rejected' => ('🙏', 'Not approved this time', 'We\'re not able to move forward with this application right now. You\'re welcome to apply again.', Colors.orange),
      _ => ('⏳', 'Application under review', 'Our team will get back to you soon. We\'ll notify you as soon as there\'s an update.', Colors.amber),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      application.status[0].toUpperCase() + application.status.substring(1),
                      style: TextStyle(color: color.shade700, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Application Details', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if ((application.city ?? '').isNotEmpty) _detailRow('City', application.city!),
                  if ((application.areaOfInterest ?? '').isNotEmpty) _detailRow('Area of Interest', application.areaOfInterest!),
                  _detailRow('Submitted', DateFormat('d MMM yyyy').format(application.createdAt.toLocal())),
                ],
              ),
            ),
          ),
          if (application.hasIdCard) ...[
            const SizedBox(height: 20),
            if (_downloadError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                child: Text(_downloadError!, style: TextStyle(color: Colors.red.shade700)),
              ),
              const SizedBox(height: 12),
            ],
            ElevatedButton.icon(
              onPressed: _downloading ? null : _downloadIdCard,
              icon: _downloading
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_outlined),
              label: const Text('Download Volunteer ID Card'),
            ),
          ],
          if (application.status == 'rejected') ...[
            const SizedBox(height: 20),
            OutlinedButton(onPressed: widget.onReapply, child: const Text('Apply Again')),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
