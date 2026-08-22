import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../state/nikah_controller.dart';

class NikahReviewScreen extends ConsumerStatefulWidget {
  const NikahReviewScreen({super.key});

  @override
  ConsumerState<NikahReviewScreen> createState() => _NikahReviewScreenState();
}

class _NikahReviewScreenState extends ConsumerState<NikahReviewScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(nikahControllerProvider.notifier).submit();
      // submit() only flips verification_status server-side and doesn't
      // update the cached profile — refresh so anything reading it after
      // this (including a user backing out before paying) sees the real
      // state instead of what was cached before submission.
      await ref.read(nikahControllerProvider.notifier).refresh();
      if (mounted) context.go('/nikah/payment');
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(nikahControllerProvider).profile;
    final l10n = AppLocalizations.of(context)!;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Review Your Profile')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  LinearProgressIndicator(value: profile.completenessPercentage / 100),
                  const SizedBox(height: 8),
                  Text('${profile.completenessPercentage}% complete', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 20),
                  _section('Basic Info', [
                    _row('Age', '${profile.age}'),
                    _row('Height', profile.height),
                    _row('Marital Status', profile.maritalStatus.replaceAll('_', ' ')),
                    _row('City', '${profile.city}${profile.state != null ? ', ${profile.state}' : ''}'),
                  ]),
                  _section('Guardian', [
                    _row('Name', profile.guardianName),
                    _row('Contact', profile.guardianContact),
                    _row('Relation', profile.guardianRelation),
                  ]),
                  _section('Deen & Lifestyle', [
                    _row('Sect', profile.sect),
                    _row('Prayer', profile.prayerFrequency),
                    _row('Education', profile.education),
                    _row('Profession', profile.profession),
                  ]),
                  _section('About', [
                    _row('About', profile.about),
                    _row('Looking for', profile.expectations),
                  ]),
                  _section('Verification', [
                    _row('CNIC Number', profile.hasCnicNumber ? '••••• (saved)' : 'Not provided'),
                    _row('CNIC Front', profile.hasCnicFrontImage ? 'Uploaded ✓' : 'Missing'),
                    _row('CNIC Back', profile.hasCnicBackImage ? 'Uploaded ✓' : 'Missing'),
                    _row('Photo', profile.hasPhoto ? 'Uploaded ✓' : 'Not added'),
                    _row('Visibility', profile.visibility),
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                children: [
                  if (!profile.isComplete)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        l10n.nikahFinishVerificationFirst,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ElevatedButton(
                    onPressed: (_busy || !profile.isComplete) ? null : _submit,
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(l10n.nikahSubmitForVerification),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
