import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/nikah_avatar.dart';
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
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendInterest() async {
    setState(() => _sendingInterest = true);
    try {
      final repo = ref.read(nikahRepositoryProvider);
      await repo.sendInterest(widget.profileId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Interest sent!')));
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sendingInterest = false);
    }
  }

  Future<void> _toggleSave() async {
    final repo = ref.read(nikahRepositoryProvider);
    final saved = await repo.toggleSave(widget.profileId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved ? 'Saved!' : 'Removed from saved.')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _detail == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error ?? 'Not found'))),
      );
    }

    final detail = _detail!;
    final card = detail.profile;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
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
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: card.trustBadges.entries.where((e) => e.value).map((e) {
                final label = switch (e.key) {
                  'payment' => '💳 Fee Paid',
                  'cnic' => '🪪 ID Verified',
                  'guardian' => '👪 Guardian Verified',
                  _ => e.key,
                };
                return Chip(label: Text(label, style: const TextStyle(fontSize: 12)));
              }).toList(),
            ),
            const SizedBox(height: 20),
            _infoRow('Marital Status', card.maritalStatus.replaceAll('_', ' ')),
            _infoRow('Height', card.height),
            _infoRow('City', card.country != null ? '${card.city}, ${card.country}' : card.city),
            _infoRow('Sect', card.sect),
            _infoRow('Prayer', card.prayerFrequency),
            _infoRow('Hijab/Beard', card.hijabOrBeard),
            _infoRow('Diet', card.diet),
            _infoRow('Education', card.education),
            _infoRow('Profession', card.profession),
            _infoRow('Family Type', card.familyType),
            _infoRow('Ethnicity', card.ethnicity),
            _infoRow('Language', card.language),
            if (card.about != null && card.about!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('About', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(card.about!),
            ],
            if (card.expectations != null && card.expectations!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Looking For', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(card.expectations!),
            ],
            const SizedBox(height: 28),
            if (detail.interestStatus == 'accepted')
              const Center(child: Text('✅ You\'re connected!', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green)))
            else if (detail.isMineSent)
              Center(
                child: Text(
                  detail.interestStatus == 'declined' ? 'Interest declined' : 'Interest sent — awaiting response',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _sendingInterest ? null : _sendInterest,
                icon: const Icon(Icons.favorite_border),
                label: Text(_sendingInterest ? 'Sending…' : 'Send Interest'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
