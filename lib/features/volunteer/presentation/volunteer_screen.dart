import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
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

String _areaOfInterestLabel(AppLocalizations l10n, String value) => {
      'Teaching': l10n.volunteerAreaTeaching,
      'Tech Support': l10n.volunteerAreaTechSupport,
      'Counseling': l10n.volunteerAreaCounseling,
      'Fundraising': l10n.volunteerAreaFundraising,
      'Event Support': l10n.volunteerAreaEventSupport,
      'Administration': l10n.volunteerAreaAdministration,
      'Other': l10n.volunteerAreaOther,
    }[value] ?? value;

String _volunteerStatusLabel(AppLocalizations l10n, String status) => {
      'pending': l10n.volunteerStatusPending,
      'approved': l10n.volunteerStatusApproved,
      'rejected': l10n.volunteerStatusRejected,
    }[status] ?? status;

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
      // Called from initState() — looked up after the await above rather
      // than hoisted, since Localizations isn't registered yet that early.
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Theme(
      data: ModuleThemes.forModule('volunteer'),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.volunteerTitle)),
        body: SafeArea(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              ElevatedButton(onPressed: _load, child: Text(l10n.retry)),
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
    final l10n = AppLocalizations.of(context)!;
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
      if (mounted) setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('🙌', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(l10n.becomeAVolunteerTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            l10n.volunteerIntroMessage,
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
            decoration: InputDecoration(labelText: l10n.cityLabel),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _areaOfInterest,
            decoration: InputDecoration(labelText: l10n.areaOfInterestLabel),
            items: _areaOfInterestOptions.map((a) => DropdownMenuItem(value: a, child: Text(_areaOfInterestLabel(l10n, a)))).toList(),
            onChanged: (v) => setState(() => _areaOfInterest = v),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _messageController,
            decoration: InputDecoration(labelText: l10n.volunteerAnythingElseHint),
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(l10n.submitApplicationButton),
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
      if (mounted) setState(() => _downloadError = AppLocalizations.of(context)!.volunteerIdCardDownloadError);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final application = widget.application;
    final (emoji, title, subtitle, color) = switch (application.status) {
      'approved' => ('🎉', l10n.volunteerApprovedTitle, l10n.volunteerApprovedSubtitle, Colors.green),
      'rejected' => ('🙏', l10n.volunteerRejectedTitle, l10n.volunteerRejectedSubtitle, Colors.orange),
      _ => ('⏳', l10n.volunteerPendingTitle, l10n.volunteerPendingSubtitle, Colors.amber),
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
                      _volunteerStatusLabel(l10n, application.status),
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
                  Text(l10n.applicationDetailsTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if ((application.city ?? '').isNotEmpty) _detailRow(l10n.cityLabel, application.city!),
                  if ((application.areaOfInterest ?? '').isNotEmpty) _detailRow(l10n.areaOfInterestLabel, _areaOfInterestLabel(l10n, application.areaOfInterest!)),
                  _detailRow(l10n.submittedLabel, DateFormat('d MMM yyyy').format(application.createdAt.toLocal())),
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
              label: Text(l10n.downloadVolunteerIdCardButton),
            ),
          ],
          if (application.status == 'rejected') ...[
            const SizedBox(height: 20),
            OutlinedButton(onPressed: widget.onReapply, child: Text(l10n.applyAgainButton)),
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
