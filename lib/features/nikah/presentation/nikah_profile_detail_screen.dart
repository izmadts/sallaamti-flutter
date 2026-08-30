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

const _reportReasons = {
  'fake_profile': 'Fake profile',
  'inappropriate_content': 'Inappropriate content',
  'harassment': 'Harassment',
  'already_married': 'Already married',
  'other': 'Other',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block this profile?'),
        content: const Text('You will no longer see each other in Browse or be able to message.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Block')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final repo = ref.read(nikahRepositoryProvider);
      await repo.blockProfile(widget.profileId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile blocked.')));
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneric)));
    }
  }

  Future<void> _report() async {
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted. Our team will review it shortly.')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneric)));
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
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'report', child: Text('Report profile')),
              PopupMenuItem(value: 'block', child: Text('Block profile')),
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
              child: Text('${card.age} years old', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text('${detail.matchPercentage}% match', style: TextStyle(color: primary, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 16),
            Center(child: TrustBadges(trustBadges: card.trustBadges)),
            const SizedBox(height: 20),
            _section('Basic Info', [
              _row('Marital Status', card.maritalStatus.replaceAll('_', ' ')),
              _row('Height', card.height),
              _row('City', card.country != null ? '${card.city}, ${card.country}' : card.city),
            ]),
            _section('Deen & Lifestyle', [
              _row('Sect', card.sect),
              _row('Prayer', card.prayerFrequency),
              _row('Hijab/Beard', card.hijabOrBeard),
              _row('Diet', card.diet),
            ]),
            _section('Background', [
              _row('Education', card.education),
              _row('Profession', card.profession),
              _row('Family Type', card.familyType),
              _row('Ethnicity', card.ethnicity),
              _row('Language', card.language),
            ]),
            if ((card.about != null && card.about!.isNotEmpty) || (card.expectations != null && card.expectations!.isNotEmpty))
              _section('About', [
                if (card.about != null && card.about!.isNotEmpty) _longText('About', card.about!),
                if (card.expectations != null && card.expectations!.isNotEmpty) _longText('Looking For', card.expectations!),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green.shade200), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('✅ Contact Information', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.green.shade800)),
          const SizedBox(height: 10),
          if ((contact.guardianName ?? '').isNotEmpty) _contactRow('Guardian Name', contact.guardianName!),
          if ((contact.guardianRelation ?? '').isNotEmpty) _contactRow('Guardian Relation', contact.guardianRelation!),
          if ((contact.guardianContact ?? '').isNotEmpty) _contactRow('Guardian Contact', contact.guardianContact!, valueColor: Colors.green.shade700),
          if (interestId != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => context.push('/nikah/interests/$interestId/messages'),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Open Messages'),
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
    return AlertDialog(
      title: const Text('Report this profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: _reportReasons.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _reason = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detailsController,
            decoration: const InputDecoration(labelText: 'Details (optional)'),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _reason == null
              ? null
              : () => Navigator.of(context).pop({'reason': _reason!, 'details': _detailsController.text.trim()}),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
