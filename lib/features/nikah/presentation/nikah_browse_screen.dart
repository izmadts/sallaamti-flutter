import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/trust_badges.dart';
import '../../../shared/widgets/whatsapp_channel_action.dart';
import '../domain/nikah_card.dart';
import '../state/nikah_controller.dart';
import 'wizard/nikah_step1_screen.dart' show maritalStatusOptions;

// Describes why a member can only teaser-browse right now — no profile at
// all, or a profile that exists but is still unpaid/unverified. Built by
// the caller (NikahHomeScreen, which already has a BuildContext/l10n) from
// one of the factories below so this file never has to know which case
// it's in beyond "is there one at all" (widget.restriction != null).
class NikahBrowseRestriction {
  final String bannerTitle;
  final String dialogTitle;
  final String dialogMessage;
  // Null actionLabel/actionRoute means there's nothing to do but wait (e.g.
  // payment/verification already submitted and under review) — the banner
  // then shows no button, and the dialog shows only a dismiss action.
  final String? actionLabel;
  final String? actionRoute;

  const NikahBrowseRestriction({
    required this.bannerTitle,
    required this.dialogTitle,
    required this.dialogMessage,
    this.actionLabel,
    this.actionRoute,
  });

  factory NikahBrowseRestriction.noProfile(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return NikahBrowseRestriction(
      bannerTitle: l10n.nikahBrowseTeaserTitle,
      dialogTitle: l10n.nikahCreateProfile,
      dialogMessage: l10n.nikahCreateProfileDialogMessage,
      actionLabel: l10n.nikahCreateProfile,
      actionRoute: '/nikah/wizard/step1',
    );
  }

  factory NikahBrowseRestriction.paymentPending(BuildContext context, {required bool rejected, String? amount}) {
    final l10n = AppLocalizations.of(context)!;
    final reason = rejected ? l10n.nikahPaymentRejectedMessage : l10n.nikahPaymentDueMessage(amount ?? '');
    return NikahBrowseRestriction(
      bannerTitle: l10n.nikahBrowseTeaserTitle,
      dialogTitle: rejected ? l10n.nikahPaymentRejectedTitle : l10n.nikahPaymentDueTitle,
      dialogMessage: '$reason\n\n${l10n.nikahCompleteStepBeforeBrowsing}',
      actionLabel: l10n.nikahPayVerificationFee,
      actionRoute: '/nikah/payment',
    );
  }

  factory NikahBrowseRestriction.paymentUnderReview(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return NikahBrowseRestriction(
      bannerTitle: l10n.nikahBrowseTeaserTitle,
      dialogTitle: l10n.nikahPaymentUnderReviewTitle,
      dialogMessage: l10n.nikahPaymentUnderReviewMessage,
    );
  }

  factory NikahBrowseRestriction.verificationPending(BuildContext context, {required bool rejected, String? rejectionReason}) {
    final l10n = AppLocalizations.of(context)!;
    return NikahBrowseRestriction(
      bannerTitle: l10n.nikahBrowseTeaserTitle,
      dialogTitle: l10n.nikahProfileUnderVerificationTitle,
      dialogMessage: rejected ? (rejectionReason ?? l10n.nikahProfileNeedsChangesMessage) : l10n.nikahProfileReviewingMessage,
      actionLabel: rejected ? l10n.nikahUpdateProfile : null,
      actionRoute: rejected ? '/nikah/wizard/step1' : null,
    );
  }
}

// Shown instead of a protected screen/action when a restricted visitor
// taps something that actually needs full eligibility (viewing a profile's
// full details, hiring a Nikah Counselor, sending interest). Browsing the
// card list itself doesn't need this; everything past it does.
void _promptRestriction(BuildContext context, NikahBrowseRestriction restriction) {
  final l10n = AppLocalizations.of(context)!;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(restriction.dialogTitle),
      content: Text(restriction.dialogMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(restriction.actionRoute != null ? l10n.nikahNotNow : l10n.nikahGotIt),
        ),
        if (restriction.actionRoute != null)
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push(restriction.actionRoute!);
            },
            child: Text(restriction.actionLabel!),
          ),
      ],
    ),
  );
}

class NikahBrowseScreen extends ConsumerStatefulWidget {
  // Set by NikahHomeScreen whenever the member can only teaser-browse right
  // now — no profile at all, or a profile that's unpaid/unverified. The
  // backend still returns the card list in every one of these cases
  // (teaser browsing, no match percentages since there's no eligible
  // profile to compare against) but gates everything past it, so this
  // mirrors that on the UI: an extra banner up top describing what's
  // pending, a Hire Counselor button that prompts for it instead of
  // opening the (also-gated) picker screen, and tapping any card prompts
  // instead of opening its detail page.
  final NikahBrowseRestriction? restriction;
  const NikahBrowseScreen({super.key, this.restriction});

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
  Map<String, String> _filters = {};

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
      final result = await repo.browse(page: _page, filters: _filters);
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
      final result = await repo.browse(page: _page, filters: _filters);
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

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FilterSheet(initial: _filters),
    );
    if (result != null) {
      setState(() => _filters = result);
      _load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('nikah'),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.restriction?.bannerTitle ?? AppLocalizations.of(context)!.nikahBrowseMatchesTitle),
          // A restriction already has its own Filter action in
          // _RestrictedBrowseHeader below — showing this one too just duplicates it.
          actions: [
            if (widget.restriction == null)
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.tune), tooltip: 'Filter', onPressed: _openFilters),
                  if (_filters.isNotEmpty)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Color(0xFFB8962E), shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
            const WhatsappChannelAction(),
          ],
        ),
        body: Column(
          children: [
            if (widget.restriction != null) _RestrictedBrowseHeader(restriction: widget.restriction!, onOpenFilters: _openFilters),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _load(reset: true),
                child: _buildBody(context),
              ),
            ),
          ],
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
      padding: const EdgeInsets.all(10),
      // 200 keeps two cards per row on a typical phone width while still
      // growing to 3+ columns automatically on a tablet, rather than being
      // pinned to a fixed crossAxisCount.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 352,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
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
          restriction: widget.restriction,
        );
      },
    );
  }
}

// The "complete this first" push shown above the grid for any restricted
// visitor — a banner button (or, when there's nothing to do but wait, just
// the title as plain text) plus a Hire Counselor shortcut next to the
// filter, matching the always-visible filter icon already in the AppBar so
// there's no need to duplicate that action here, just make it more visible
// for a visitor who hasn't learned where it lives yet.
class _RestrictedBrowseHeader extends StatelessWidget {
  final NikahBrowseRestriction restriction;
  final VoidCallback onOpenFilters;
  const _RestrictedBrowseHeader({required this.restriction, required this.onOpenFilters});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      color: primary,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (restriction.actionRoute != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(restriction.actionRoute!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(restriction.actionLabel!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            )
          else
            Text(
              restriction.dialogTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: onOpenFilters,
                icon: const Icon(Icons.tune, color: Colors.white),
                label: Text(l10n.nikahFilter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              // Expanded (not a bare OutlinedButton) so long text or a wider
              // system font scale shrinks/wraps instead of silently
              // overflowing off-screen with no release-mode warning.
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _promptRestriction(context, restriction),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white), foregroundColor: Colors.white),
                  child: Text(l10n.nikahHireCounselorAction, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NikahCardTile extends StatefulWidget {
  final NikahCard card;
  final NikahBrowseRestriction? restriction;
  const _NikahCardTile({super.key, required this.card, this.restriction});

  @override
  State<_NikahCardTile> createState() => _NikahCardTileState();
}

class _NikahCardTileState extends State<_NikahCardTile> {
  late bool _saved = widget.card.isSaved;
  late bool _sent = widget.card.hasSentInterest;
  bool _savingBusy = false;
  bool _sendingBusy = false;

  Future<void> _toggleSave() async {
    if (widget.restriction != null) {
      _promptRestriction(context, widget.restriction!);
      return;
    }
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
    if (widget.restriction != null) {
      _promptRestriction(context, widget.restriction!);
      return;
    }
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
    // CNIC is the one badge that reflects an actual document check by our
    // team, not just a payment or a self-reported contact — so it's the
    // signal that earns a card a visibly more prominent, trusted look.
    final isCnicVerified = card.trustBadges['cnic'] == true;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: isCnicVerified ? 3 : 1,
      shadowColor: isCnicVerified ? const Color(0xFF10B981).withValues(alpha: 0.4) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: isCnicVerified ? const BorderSide(color: Color(0xFF10B981), width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: widget.restriction != null ? () => _promptRestriction(context, widget.restriction!) : () => context.push('/nikah/profile/${card.id}'),
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
                                  : Text(
                                      _sent ? 'Sent ✓' : '💌 Send Interest',
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
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

// Kept to a handful of the fields the backend already supports (full list:
// city/sect/education/ethnicity/language/family_type/state/country/age
// range/marital_status/prayer_frequency/open_to_polygamy) — the ones a
// member is actually likely to filter by, not every field just because the
// API accepts it.
class _FilterSheet extends StatefulWidget {
  final Map<String, String> initial;
  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final _cityController = TextEditingController(text: widget.initial['city']);
  late final _sectController = TextEditingController(text: widget.initial['sect']);
  late final _minAgeController = TextEditingController(text: widget.initial['min_age']);
  late final _maxAgeController = TextEditingController(text: widget.initial['max_age']);
  String? _maritalStatus;

  @override
  void initState() {
    super.initState();
    _maritalStatus = widget.initial['marital_status'];
  }

  @override
  void dispose() {
    _cityController.dispose();
    _sectController.dispose();
    _minAgeController.dispose();
    _maxAgeController.dispose();
    super.dispose();
  }

  void _apply() {
    final filters = <String, String>{
      if (_cityController.text.trim().isNotEmpty) 'city': _cityController.text.trim(),
      if (_sectController.text.trim().isNotEmpty) 'sect': _sectController.text.trim(),
      if (_minAgeController.text.trim().isNotEmpty) 'min_age': _minAgeController.text.trim(),
      if (_maxAgeController.text.trim().isNotEmpty) 'max_age': _maxAgeController.text.trim(),
      if (_maritalStatus != null) 'marital_status': _maritalStatus!,
    };
    Navigator.of(context).pop(filters);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Filter Matches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _minAgeController,
                  decoration: const InputDecoration(labelText: 'Min Age'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _maxAgeController,
                  decoration: const InputDecoration(labelText: 'Max Age'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _cityController,
            decoration: const InputDecoration(labelText: 'City'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _sectController,
            decoration: const InputDecoration(labelText: 'Sect'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _maritalStatus,
            decoration: const InputDecoration(labelText: 'Marital Status'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Any')),
              ...maritalStatusOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
            ],
            onChanged: (v) => setState(() => _maritalStatus = v),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(<String, String>{}),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(onPressed: _apply, child: const Text('Apply')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
