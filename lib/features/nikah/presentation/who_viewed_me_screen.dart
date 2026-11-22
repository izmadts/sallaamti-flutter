import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/nikah_card.dart';
import '../state/nikah_controller.dart';

// Reachable by any member with a profile — pending or verified, see
// NikahRepository.whoViewedMe()'s own comment — not gated behind the same
// payment/verification wall as browsing others.
class WhoViewedMeScreen extends ConsumerStatefulWidget {
  const WhoViewedMeScreen({super.key});

  @override
  ConsumerState<WhoViewedMeScreen> createState() => _WhoViewedMeScreenState();
}

class _WhoViewedMeScreenState extends ConsumerState<WhoViewedMeScreen> {
  late Future<List<NikahCard>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = ref.read(nikahRepositoryProvider).whoViewedMe();

  void _reload() => setState(_load);

  String _timeAgo(AppLocalizations l10n, DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return l10n.timeAgoMinutes(diff.inMinutes);
    if (diff.inHours < 24) return l10n.timeAgoHours(diff.inHours);
    if (diff.inDays < 30) return l10n.timeAgoDays(diff.inDays);
    return l10n.timeAgoMonths((diff.inDays / 30).floor());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Theme(
      data: ModuleThemes.forModule('nikah'),
      child: Scaffold(
        appBar: AppBar(title: Text('👀 ${l10n.nikahWhoViewedMyProfileTitle}')),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => _reload(),
            child: FutureBuilder<List<NikahCard>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  final message = snapshot.error is ApiException ? (snapshot.error as ApiException).displayMessage : l10n.errorGeneric;
                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Text(message, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _reload, child: Text(l10n.nikahTryAgain)),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                final views = snapshot.data!;
                if (views.isEmpty) {
                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const Text('👀', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(l10n.nikahNoOneViewedYetTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16), textAlign: TextAlign.center),
                            const SizedBox(height: 6),
                            Text(
                              l10n.nikahNoOneViewedYetMessage,
                              style: TextStyle(color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: views.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ViewerTile(
                    card: views[i],
                    timeAgoLabel: views[i].lastViewedAt != null ? _timeAgo(l10n, views[i].lastViewedAt!) : null,
                    onTap: () => context.push('/nikah/profile/${views[i].id}'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewerTile extends StatelessWidget {
  final NikahCard card;
  final String? timeAgoLabel;
  final VoidCallback onTap;
  const _ViewerTile({required this.card, required this.timeAgoLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: card.photoUrl != null ? _AuthedThumbnail(url: card.photoUrl!) : Container(
                    color: Colors.teal.withValues(alpha: 0.08),
                    child: const Center(child: Text('👤', style: TextStyle(fontSize: 26))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [if (card.age > 0) '${card.age} yrs', if (card.city.isNotEmpty) card.city].join(' · '),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    if ((card.profession ?? card.sect) != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        [card.profession, card.sect].where((e) => e != null && e.isNotEmpty).join(' · '),
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (timeAgoLabel != null)
                    Text(timeAgoLabel!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                  if ((card.viewCount ?? 0) > 1) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(999)),
                      child: Text(l10n.nikahViewedCountLabel(card.viewCount ?? 0), style: TextStyle(fontSize: 10.5, color: Colors.amber.shade800, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthedThumbnail extends StatelessWidget {
  final String url;
  const _AuthedThumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: SecureStore.readToken(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return Image.network(
          url,
          headers: {'Authorization': 'Bearer ${snapshot.data}'},
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => Container(
            color: Colors.teal.withValues(alpha: 0.08),
            child: const Center(child: Text('👤', style: TextStyle(fontSize: 26))),
          ),
        );
      },
    );
  }
}
