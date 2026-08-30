import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/trust_badges.dart';
import '../domain/nikah_card.dart';
import '../state/nikah_controller.dart';

class NikahBrowseScreen extends ConsumerStatefulWidget {
  const NikahBrowseScreen({super.key});

  @override
  ConsumerState<NikahBrowseScreen> createState() => _NikahBrowseScreenState();
}

class _NikahBrowseScreenState extends ConsumerState<NikahBrowseScreen> {
  final List<NikahCard> _profiles = [];
  final _scrollController = ScrollController();
  int _page = 1;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    // Infinite scroll — a "Load More" button remains too (further down,
    // once scrolled past what auto-loads), so either way of reaching more
    // results works.
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 400) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    _page++;
    try {
      final repo = ref.read(nikahRepositoryProvider);
      final result = await repo.browse(page: _page);
      if (mounted) {
        setState(() {
          _profiles.addAll(result.profiles);
          _hasMore = result.hasMore;
        });
      }
    } catch (_) {
      _page--; // let the manual "Load More" button retry the same page
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('nikah'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Browse Matches')),
        body: RefreshIndicator(
          onRefresh: () => _load(reset: true),
          child: _buildBody(context),
        ),
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

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        mainAxisExtent: 340,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _profiles.length + 1,
      itemBuilder: (context, index) {
        if (index == _profiles.length) {
          if (!_hasMore) return const SizedBox.shrink();
          return Center(
            child: _loadingMore
                ? const CircularProgressIndicator()
                : OutlinedButton(onPressed: _loadMore, child: Text(AppLocalizations.of(context)!.nikahLoadMore)),
          );
        }
        return _NikahCardTile(
          key: ValueKey(_profiles[index].id),
          card: _profiles[index],
        );
      },
    );
  }
}

class _NikahCardTile extends StatefulWidget {
  final NikahCard card;
  const _NikahCardTile({super.key, required this.card});

  @override
  State<_NikahCardTile> createState() => _NikahCardTileState();
}

class _NikahCardTileState extends State<_NikahCardTile> {
  late bool _saved = widget.card.isSaved;
  late bool _sent = widget.card.hasSentInterest;
  bool _savingBusy = false;
  bool _sendingBusy = false;

  Future<void> _toggleSave() async {
    setState(() => _savingBusy = true);
    try {
      final repo = ProviderScope.containerOf(context).read(nikahRepositoryProvider);
      final saved = await repo.toggleSave(widget.card.id);
      if (mounted) setState(() => _saved = saved);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update saved status — try again.')));
      }
    } finally {
      if (mounted) setState(() => _savingBusy = false);
    }
  }

  Future<void> _sendInterest() async {
    setState(() => _sendingBusy = true);
    try {
      final repo = ProviderScope.containerOf(context).read(nikahRepositoryProvider);
      await repo.sendInterest(widget.card.id);
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send interest — try again.')));
      }
    } finally {
      if (mounted) setState(() => _sendingBusy = false);
    }
  }

  String _memberSince(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return 'Member since ${months[date.month - 1]} ${date.year}';
  }

  String _activeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'Active ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Active ${diff.inHours}h ago';
    return 'Active ${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final tags = [
      if (card.profession != null && card.profession!.isNotEmpty) '💼 ${card.profession}',
      if (card.education != null && card.education!.isNotEmpty) '🎓 ${card.education}',
      if (card.sect != null && card.sect!.isNotEmpty) '☪️ ${card.sect}',
      if (card.ethnicity != null && card.ethnicity!.isNotEmpty) '🌍 ${card.ethnicity}',
    ];
    final isRecentlyActive = card.lastActiveAt != null && DateTime.now().difference(card.lastActiveAt!).inDays < 7;
    final isNew = card.createdAt != null && DateTime.now().difference(card.createdAt!).inDays < 14;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () => context.push('/nikah/profile/${card.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo banner with badges overlaid, matching the website card.
            SizedBox(
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.teal.withValues(alpha: 0.06),
                    child: card.photoUrl != null
                        ? _BlurredBannerPhoto(photoUrl: card.photoUrl!)
                        : const Center(child: Text('👤', style: TextStyle(fontSize: 48, color: Colors.black26))),
                  ),
                  if (card.photoUrl != null)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20)),
                          child: const Text('🔒 Photo hidden', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: TrustBadges(trustBadges: card.trustBadges, small: true, direction: Axis.vertical),
                  ),
                  if (isNew)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: _Pill(text: '✨ New', color: const Color(0xFFCA8A04)),
                    ),
                  if (card.matchPercentage > 0)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: _Pill(
                        text: '${card.matchPercentage}% match',
                        color: card.matchPercentage >= 80
                            ? Colors.green.shade600
                            : (card.matchPercentage >= 50 ? Colors.amber.shade700 : Colors.grey.shade600),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${card.age} yrs · ${card.city}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (card.gender != null) ...[
                          const SizedBox(width: 6),
                          _Pill(
                            text: card.gender == 'female' ? '♀ Female' : '♂ Male',
                            color: card.gender == 'female' ? Colors.pink.shade400 : Colors.blue.shade400,
                            small: true,
                          ),
                        ],
                      ],
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        tags.join('   '),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            card.maritalStatus.replaceAll('_', ' '),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            isRecentlyActive ? _activeAgo(card.lastActiveAt!) : (card.createdAt != null ? _memberSince(card.createdAt!) : ''),
                            style: TextStyle(
                              fontSize: 11,
                              color: isRecentlyActive ? Colors.green.shade700 : Colors.grey.shade500,
                              fontWeight: isRecentlyActive ? FontWeight.w600 : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              onPressed: (_sent || _sendingBusy) ? null : _sendInterest,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                disabledBackgroundColor: Colors.grey.shade200,
                                padding: EdgeInsets.zero,
                              ),
                              child: _sendingBusy
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text(_sent ? 'Sent ✓' : '💌 Express Interest', style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          height: 36,
                          width: 36,
                          child: OutlinedButton(
                            onPressed: _savingBusy ? null : _toggleSave,
                            style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                            child: _savingBusy
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(_saved ? Icons.star : Icons.star_border, color: _saved ? Colors.amber.shade600 : Colors.grey.shade400, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Full-width, blurred (photo stays hidden until mutual interest is
// accepted — the profile IS the point, not the picture) — an
// authenticated network image, unlike NikahAvatar this fills a
// rectangular banner rather than a small circle.
class _BlurredBannerPhoto extends StatelessWidget {
  final String photoUrl;
  const _BlurredBannerPhoto({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: SecureStore.readToken(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Image.network(
            photoUrl,
            headers: {'Authorization': 'Bearer ${snapshot.data}'},
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stack) => const Center(child: Text('👤', style: TextStyle(fontSize: 48, color: Colors.black26))),
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final bool small;
  const _Pill({required this.text, required this.color, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 10, vertical: small ? 2 : 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: Colors.white, fontSize: small ? 10 : 11, fontWeight: FontWeight.w700)),
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
