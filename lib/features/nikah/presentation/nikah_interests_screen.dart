import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/nikah_avatar.dart';
import '../domain/nikah_interest.dart';
import '../state/nikah_controller.dart';

class NikahInterestsScreen extends ConsumerStatefulWidget {
  const NikahInterestsScreen({super.key});

  @override
  ConsumerState<NikahInterestsScreen> createState() => _NikahInterestsScreenState();
}

class _NikahInterestsScreenState extends ConsumerState<NikahInterestsScreen> {
  List<NikahInterest> _received = [];
  List<NikahInterest> _sent = [];
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
      final repo = ref.read(nikahRepositoryProvider);
      final result = await repo.listInterests();
      setState(() {
        _received = result.received;
        _sent = result.sent;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(int interestId, bool accept) async {
    // Accepting reveals the guardian's real name/contact number to the
    // other side immediately, with no further review step — worth a pause,
    // since this is exactly the moment a fake-matchmaker/scam profile would
    // be counting on a quick tap. Declining shares nothing, so it skips
    // straight through.
    if (accept) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Accept this interest?'),
          content: const Text(
            'Accepting will share your guardian\'s contact details with this person. Please check their verification badges on their full profile first.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Accept')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final repo = ref.read(nikahRepositoryProvider);
    try {
      if (accept) {
        await repo.acceptInterest(interestId);
      } else {
        await repo.declineInterest(interestId);
      }
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneric)));
    }
  }

  Future<void> _cancel(int interestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this interest request?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes, Cancel')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(nikahRepositoryProvider).cancelInterest(interestId);
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
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Interests'),
            bottom: const TabBar(
              // Explicit colors — the default TabBarTheme resolves both label
              // colors close to the module's own AppBar background, making
              // the selected tab's text disappear entirely and the
              // unselected one nearly unreadable.
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [Tab(text: 'Received'), Tab(text: 'Sent')],
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
                  : TabBarView(
                      children: [
                        _list(_received, showActions: true),
                        _list(_sent, showActions: false, allowCancel: true),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _list(List<NikahInterest> items, {required bool showActions, bool allowCancel = false}) {
    if (items.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.nikahNothingHereYet));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final interest = items[index];
          final inactive = interest.isInactive;
          final pendingAndActive = interest.status == 'pending' && !inactive;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: inactive ? Colors.grey.shade100 : null,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: inactive ? null : () => context.push('/nikah/profile/${interest.profileId}'),
              child: Opacity(
                opacity: inactive ? 0.6 : 1,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          interest.unavailable || interest.blocked
                              ? CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Colors.grey.shade300,
                                  child: Icon(Icons.person_off_outlined, color: Colors.grey.shade600, size: 24),
                                )
                              : NikahAvatar(photoUrl: interest.photoUrl, radius: 26),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  interest.unavailable || interest.blocked
                                      ? 'This profile is no longer available'
                                      : (interest.name ?? '${interest.age ?? '?'} yrs • ${interest.city ?? ''}'),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                if (!interest.unavailable && !interest.blocked && interest.profession != null)
                                  Text(interest.profession!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                const SizedBox(height: 4),
                                _StatusPill(status: interest.status, blocked: interest.blocked),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (showActions && pendingAndActive) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _respond(interest.interestId, true),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Accept'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _respond(interest.interestId, false),
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text('Decline'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                  side: BorderSide(color: Colors.red.shade200),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (allowCancel && pendingAndActive) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _cancel(interest.interestId),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Cancel Request'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade200),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final bool blocked;
  const _StatusPill({required this.status, this.blocked = false});

  @override
  Widget build(BuildContext context) {
    final label = blocked ? 'blocked' : status;
    final color = blocked
        ? Colors.grey.shade700
        : switch (status) {
            'accepted' => Colors.green,
            'declined' => Colors.red,
            _ => Colors.orange,
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
