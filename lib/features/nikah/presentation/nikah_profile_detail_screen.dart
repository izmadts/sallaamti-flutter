import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/nikah_avatar.dart';
import '../../../shared/widgets/trust_badges.dart';
import '../data/nikah_repository.dart';
import '../state/nikah_controller.dart';

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
            if (detail.interestStatus == 'accepted')
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
