import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/nikah_avatar.dart';
import '../domain/matchmaking_overview.dart';
import '../state/nikah_controller.dart';

// "My Matchmaker" — proposals and consent requests from the member's own
// Nikah Counselor, surfaced inside the app itself. Replacement for the
// public /p/{lead} token link's matching self-service (see
// Api\V1\NikahMatchmakingController's class docblock).
class NikahMatchmakingScreen extends ConsumerStatefulWidget {
  const NikahMatchmakingScreen({super.key});

  @override
  ConsumerState<NikahMatchmakingScreen> createState() => _NikahMatchmakingScreenState();
}

class _NikahMatchmakingScreenState extends ConsumerState<NikahMatchmakingScreen> {
  NikahMatchmakingOverview? _overview;
  bool _loading = true;
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
      final overview = await ref.read(nikahRepositoryProvider).matchmakingOverview();
      if (mounted) setState(() => _overview = overview);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respondToProposal(NikahProposal proposal, String response) async {
    // Same pause as the regular Interests screen's accept action — an
    // "interested" response here also bridges into a real NikahInterest,
    // which reveals the guardian's contact to the candidate immediately.
    if (response == 'interested') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Interested in this candidate?'),
          content: const Text('This will share your guardian\'s contact details with them once they accept. Please check their verification badges first.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes, I\'m Interested')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    try {
      await ref.read(nikahRepositoryProvider).respondToProposal(proposal.id, response);
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneric)));
    }
  }

  Future<void> _respondToConsent(NikahConsentRequest request, String decision) async {
    try {
      await ref.read(nikahRepositoryProvider).respondToConsent(request.id, decision);
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneric)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('nikah'),
      child: Scaffold(
        appBar: AppBar(title: const Text('My Matchmaker')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
                : _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final overview = _overview;
    if (overview == null) return const SizedBox.shrink();

    final allProposals = overview.proposalBatches.expand((b) => b.proposals).toList();

    if (allProposals.isEmpty && overview.consentRequests.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.nikahNothingHereYet));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (overview.consentRequests.isNotEmpty) ...[
            const Text('Consent Requested', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            ...overview.consentRequests.map((cr) => _ConsentCard(request: cr, onRespond: (decision) => _respondToConsent(cr, decision))),
            const SizedBox(height: 20),
          ],
          if (allProposals.isNotEmpty) ...[
            const Text('Proposed Matches', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            ...allProposals.map((p) => _ProposalCard(
                  proposal: p,
                  onRespond: (response) => _respondToProposal(p, response),
                  onTap: () => context.push('/nikah/profile/${p.candidate.id}'),
                )),
          ],
        ],
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  final NikahConsentRequest request;
  final void Function(String decision) onRespond;
  const _ConsentCard({required this.request, required this.onRespond});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(request.consentLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onRespond('grant'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                    child: const Text('Agree'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onRespond('decline'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700, side: BorderSide(color: Colors.red.shade200)),
                    child: const Text('Not Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final NikahProposal proposal;
  final void Function(String response) onRespond;
  final VoidCallback onTap;
  const _ProposalCard({required this.proposal, required this.onRespond, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final candidate = proposal.candidate;
    final pending = proposal.status != 'responded';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  NikahAvatar(photoUrl: candidate.photoUrl, radius: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${candidate.age} yrs • ${candidate.city}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (candidate.profession != null) Text(candidate.profession!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        if (!pending) ...[
                          const SizedBox(height: 4),
                          _ResponsePill(response: proposal.response),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (proposal.matchReasons.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: proposal.matchReasons
                      .map((r) => Chip(label: Text(r, style: const TextStyle(fontSize: 11)), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact))
                      .toList(),
                ),
              ],
              if (pending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => onRespond('interested'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                        child: const Text('Interested'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onRespond('not_interested'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700, side: BorderSide(color: Colors.red.shade200)),
                        child: const Text('Not Interested'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponsePill extends StatelessWidget {
  final String? response;
  const _ResponsePill({this.response});

  @override
  Widget build(BuildContext context) {
    final color = switch (response) {
      'interested' => Colors.green,
      'not_interested' => Colors.red,
      _ => Colors.orange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(response ?? 'maybe', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
