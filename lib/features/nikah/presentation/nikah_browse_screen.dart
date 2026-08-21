import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/nikah_avatar.dart';
import '../domain/nikah_card.dart';
import '../state/nikah_controller.dart';

class NikahBrowseScreen extends ConsumerStatefulWidget {
  const NikahBrowseScreen({super.key});

  @override
  ConsumerState<NikahBrowseScreen> createState() => _NikahBrowseScreenState();
}

class _NikahBrowseScreenState extends ConsumerState<NikahBrowseScreen> {
  final List<NikahCard> _profiles = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _profiles.clear();
      }
    });

    try {
      final repo = ref.read(nikahRepositoryProvider);
      final result = await repo.browse(page: _page);
      setState(() {
        _profiles.addAll(result.profiles);
        _hasMore = result.hasMore;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    _page++;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browse Matches')),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _profiles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _profiles.isEmpty) {
      return _NikahGateNotice(error: _error!);
    }

    if (_profiles.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text(AppLocalizations.of(context)!.nikahNoMatchesYet)),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _profiles.length + 1,
      itemBuilder: (context, index) {
        if (index == _profiles.length) {
          if (!_hasMore) return const SizedBox(height: 24);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : OutlinedButton(onPressed: _loadMore, child: Text(AppLocalizations.of(context)!.nikahLoadMore)),
            ),
          );
        }
        return _NikahCardTile(card: _profiles[index]);
      },
    );
  }
}

class _NikahCardTile extends StatelessWidget {
  final NikahCard card;
  const _NikahCardTile({required this.card});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/nikah/profile/${card.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NikahAvatar(photoUrl: card.photoUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${card.age} yrs', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                          child: Text('${card.matchPercentage}% match', style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${card.city}${card.country != null ? ', ${card.country}' : ''}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    if (card.profession != null) Text(card.profession!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    if (card.hasSentInterest) ...[
                      const SizedBox(height: 6),
                      const Text('Interest sent ✓', style: TextStyle(fontSize: 12, color: Colors.green)),
                    ],
                  ],
                ),
              ),
              Icon(card.isSaved ? Icons.bookmark : Icons.bookmark_border, color: primary),
            ],
          ),
        ),
      ),
    );
  }
}

// Shown when browse is gated (no profile / payment pending / not verified
// yet) — the API returns a specific code+message for each, which is
// friendlier than a generic error screen.
class _NikahGateNotice extends StatelessWidget {
  final String error;
  const _NikahGateNotice({required this.error});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Text('🔒', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => context.go('/nikah'), child: Text(AppLocalizations.of(context)!.nikahBackToNikah)),
            ],
          ),
        ),
      ],
    );
  }
}
