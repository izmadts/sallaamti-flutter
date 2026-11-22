import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/nikah_avatar.dart';
import '../../../shared/widgets/trust_badges.dart';
import '../data/nikah_repository.dart';
import '../state/nikah_controller.dart';

Map<String, String> _reportReasons(AppLocalizations l10n) => {
      'fake_profile': l10n.nikahReportReasonFakeProfile,
      'fake_matchmaker': l10n.nikahReportReasonFakeMatchmaker,
      'inappropriate_content': l10n.nikahReportReasonInappropriateContent,
      'money_request': l10n.nikahReportReasonMoneyRequest,
      'harassment': l10n.nikahReportReasonHarassment,
      'already_married': l10n.nikahReportReasonAlreadyMarried,
      'other': l10n.nikahReportReasonOther,
    };

// Marital status used to just be the raw enum value with underscores
// swapped for spaces (e.g. "never married") — never actually translated.
Map<String, String> _maritalStatusLabels(AppLocalizations l10n) => {
      'never_married': l10n.maritalStatusNeverMarried,
      'divorced': l10n.maritalStatusDivorced,
      'widowed': l10n.maritalStatusWidowed,
      'separated': l10n.maritalStatusSeparated,
      'married': l10n.maritalStatusMarried,
    };

class NikahProfileDetailScreen extends ConsumerStatefulWidget {
  final int profileId;
  const NikahProfileDetailScreen({super.key, required this.profileId});

  @override
  ConsumerState<NikahProfileDetailScreen> createState() => _NikahProfileDetailScreenState();
}

class _NikahProfileDetailScreenState extends ConsumerState<NikahProfileDetailScreen> {
  NikahProfileDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _sendingInterest = false;

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
      final repo = ref.read(nikahRepositoryProvider);
      final detail = await repo.viewProfile(widget.profileId);
      setState(() => _detail = detail);
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendInterest() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _sendingInterest = true);
    try {
      final repo = ref.read(nikahRepositoryProvider);
      await repo.sendInterest(widget.profileId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.nikahInterestSent)));
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    } finally {
      if (mounted) setState(() => _sendingInterest = false);
    }
  }

  // Previously had no error handling at all — a failed save/unsave (e.g.
  // no connection) crashed silently with no feedback and no way to know
  // it hadn't actually happened.
  Future<void> _toggleSave() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final repo = ref.read(nikahRepositoryProvider);
      final saved = await repo.toggleSave(widget.profileId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved ? l10n.nikahSaved : l10n.nikahRemovedFromSaved)));
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    }
  }

  Future<void> _block() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.nikahBlockDialogTitle),
        content: Text(l10n.nikahBlockDialogMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.block)),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final repo = ref.read(nikahRepositoryProvider);
      await repo.blockProfile(widget.profileId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.nikahProfileBlockedMessage)));
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    }
  }

  Future<void> _report() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _ReportDialog(interestId: _detail?.interestId),
    );
    if (result == null) return;

    try {
      final repo = ref.read(nikahRepositoryProvider);
      await repo.reportProfile(
        widget.profileId,
        reason: result['reason']!,
        details: result['details']?.isEmpty ?? true ? null : result['details'],
        interestId: _detail?.interestId,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.nikahReportSubmittedMessage)));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _detail == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error ?? l10n.nikahNothingHereYet))),
      );
    }

    final detail = _detail!;
    final card = detail.profile;
    final primary = Theme.of(context).colorScheme.primary;

    return Theme(
      data: ModuleThemes.forModule('nikah'),
      child: Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(detail.isSaved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _toggleSave,
          ),
          PopupMenuButton<String>(
            onSelected: (value) => value == 'block' ? _block() : _report(),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'report', child: Text(l10n.nikahReportProfileMenuItem)),
              PopupMenuItem(value: 'block', child: Text(l10n.nikahBlockProfileMenuItem)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: NikahAvatar(photoUrl: card.photoUrl, radius: 56)),
            const SizedBox(height: 16),
            Center(
              child: Text(l10n.nikahAgeYearsOld(card.age), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(l10n.nikahMatchPercentage(detail.matchPercentage), style: TextStyle(color: primary, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 16),
            Center(child: TrustBadges(trustBadges: card.trustBadges)),
            const SizedBox(height: 20),
            _section(l10n.nikahBasicInfoTitle, [
              _row(l10n.maritalStatusLabel, _maritalStatusLabels(l10n)[card.maritalStatus] ?? card.maritalStatus),
              _row(l10n.heightLabel, card.height),
              _row(l10n.cityLabel, card.country != null ? '${card.city}, ${card.country}' : card.city),
            ]),
            _section(l10n.nikahDeenLifestyleTitle, [
              _row(l10n.sectLabel, card.sect),
              _row(l10n.prayerLabel, card.prayerFrequency),
              _row(l10n.hijabBeardLabel, card.hijabOrBeard),
              _row(l10n.dietLabel, card.diet),
            ]),
            _section(l10n.nikahBackgroundTitle, [
              _row(l10n.educationLabel, card.education),
              _row(l10n.professionLabel, card.profession),
              _row(l10n.familyTypeLabel, card.familyType),
              _row(l10n.ethnicityLabel, card.ethnicity),
              _row(l10n.languageLabel, card.language),
            ]),
            if ((card.about != null && card.about!.isNotEmpty) || (card.expectations != null && card.expectations!.isNotEmpty))
              _section(l10n.aboutLabel, [
                if (card.about != null && card.about!.isNotEmpty) _longText(l10n.aboutLabel, card.about!),
                if (card.expectations != null && card.expectations!.isNotEmpty) _longText(l10n.lookingForLabel, card.expectations!),
              ]),
            const SizedBox(height: 8),
            if (detail.hasAcceptedInterest && detail.contact != null)
              _ContactCard(contact: detail.contact!, interestId: detail.interestId)
            else if (detail.interestStatus == 'accepted')
              Center(child: Text('✅ ${l10n.nikahYouAreConnected}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.green)))
            else if (detail.isMineSent)
              Center(
                child: Text(
                  detail.interestStatus == 'declined' ? l10n.nikahInterestDeclinedStatus : l10n.nikahInterestAwaiting,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _sendingInterest ? null : _sendInterest,
                icon: const Icon(Icons.favorite_border),
                label: Text(_sendingInterest ? l10n.nikahSending : l10n.nikahSendInterest),
              ),
          ],
        ),
      ),
      ),
    );
  }

  // Hides the whole card, not just a blank title, when every field in it
  // is missing — e.g. a profile with no sect/prayer/hijab/diet set at all
  // shouldn't show an empty "Deen & Lifestyle" card.
  Widget _section(String title, List<Widget?> rows) {
    final visibleRows = rows.whereType<Widget>().toList();
    if (visibleRows.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            ...visibleRows,
          ],
        ),
      ),
    );
  }

  Widget? _row(String label, String? value) {
    if (value == null || value.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _longText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// Only ever shown once mutual acceptance has already happened server-side
// (NikahBrowseController::show()'s has_accepted_interest gate) — mirrors
// resources/views/nikah/profile-view.blade.php's "Contact Information" card
// exactly, plus a way into the guardian-mediated message thread.
class _ContactCard extends StatelessWidget {
  final NikahContactInfo contact;
  final int? interestId;
  const _ContactCard({required this.contact, this.interestId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green.shade200), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('✅ ${l10n.nikahContactInformationTitle}', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.green.shade800)),
          const SizedBox(height: 10),
          if ((contact.guardianName ?? '').isNotEmpty) _contactRow(l10n.guardianNameLabel, contact.guardianName!),
          if ((contact.guardianRelation ?? '').isNotEmpty) _contactRow(l10n.guardianRelationLabel, contact.guardianRelation!),
          if ((contact.guardianContact ?? '').isNotEmpty) _contactRow(l10n.guardianContactLabel, contact.guardianContact!, valueColor: Colors.green.shade700),
          if (interestId != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => context.push('/nikah/interests/$interestId/messages'),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: Text(l10n.nikahOpenMessagesButton),
            ),
          ],
        ],
      ),
    );
  }

  Widget _contactRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: valueColor)),
        ],
      ),
    );
  }
}

class _ReportDialog extends StatefulWidget {
  final int? interestId;
  const _ReportDialog({this.interestId});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _reason;
  final _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.nikahReportThisProfileTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: InputDecoration(labelText: l10n.reasonLabel),
            items: _reportReasons(l10n).entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _reason = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detailsController,
            decoration: InputDecoration(labelText: l10n.nikahDetailsOptionalLabel),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _reason == null
              ? null
              : () => Navigator.of(context).pop({'reason': _reason!, 'details': _detailsController.text.trim()}),
          child: Text(l10n.submitLabel),
        ),
      ],
    );
  }
}
