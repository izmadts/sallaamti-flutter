import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/first_visit_tour.dart';
import '../../../shared/widgets/whatsapp_channel_action.dart';
import '../data/nikah_hire_repository.dart';
import '../domain/nikah_profile.dart';
import '../state/nikah_controller.dart';
import 'nikah_browse_screen.dart';
import 'wizard/nikah_step1_screen.dart' show needsFamilyDetailsStatuses;

// "Continue Setup" used to always jump to step2 — fine for a profile with
// nothing filled in yet, but a counselor-created profile reaching mobile
// for the first time usually already has steps 1-3 done (the counselor's
// web wizard requires most of it) and is missing only CNIC/photo (step4,
// the one thing isComplete actually checks). Landing on step2 showed
// already-filled fields and left the real gap three screens away with no
// indication it was even there — exactly the kind of dead-end a less
// tech-savvy member has no way to work out on their own. Checks each
// step's own required fields in order instead of assuming step2.
String _nextIncompleteStepRoute(NikahProfile profile) {
  final needsFamilyDetails = needsFamilyDetailsStatuses.contains(profile.maritalStatus);
  if ((profile.height ?? '').isEmpty ||
      (profile.guardianName ?? '').isEmpty ||
      (profile.guardianContact ?? '').isEmpty ||
      (needsFamilyDetails && profile.hasChildren == null) ||
      (needsFamilyDetails && (profile.livingSituation ?? '').isEmpty)) {
    return '/nikah/wizard/step1';
  }
  if ((profile.sect ?? '').isEmpty || (profile.education ?? '').isEmpty || (profile.profession ?? '').isEmpty) {
    return '/nikah/wizard/step2';
  }
  if ((profile.expectations ?? '').isEmpty) {
    return '/nikah/wizard/step3';
  }
  return '/nikah/wizard/step4';
}

// Shown once (per device, see FirstVisitTour) the first time a member
// reaches the fully-set-up Nikah hub — a common user's first real exposure
// to how the module actually works, which earlier audits this session
// found is exactly where less tech-savvy members get lost. Content mirrors
// the hub tiles' own order below.
const _nikahTourSteps = [
  TourStep(
    emoji: '💍',
    title: 'Your profile is live!',
    description:
        'Verified members can now find and send interest in your profile. Sallaamti is for serious proposals — your guardian stays involved at every step, as it should be.',
  ),
  TourStep(
    emoji: '🔎',
    title: 'Browse Matches',
    description: 'Search verified profiles filtered by what actually matters to you — sect, education, city, and more.',
  ),
  TourStep(
    emoji: '💌',
    title: 'Interests & Messages',
    description:
        'When someone shows interest in you, or you in them, it shows up here. Accept it and guardian contact details are shared so families can connect.',
  ),
  TourStep(
    emoji: '⭐',
    title: 'Saved Profiles',
    description: 'Found someone promising while browsing? Star their profile to come back to it later.',
  ),
  TourStep(
    emoji: '⚙️',
    title: 'Edit Profile',
    description: 'Update your details any time — a complete, honest profile gets better, more serious matches.',
  ),
];

class NikahHomeScreen extends ConsumerWidget {
  const NikahHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nikahControllerProvider);

    if (state.status == NikahLoadStatus.loading) {
      return Theme(
        data: ModuleThemes.forModule('nikah'),
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // No profile yet — a teaser browse screen (own Scaffold/AppBar) rather
    // than this screen's own "create a profile" prompt, so a first-time
    // visitor sees real profiles (and the reason to sign up) immediately
    // instead of a bare button. See NikahBrowseRestriction's doc.
    if (state.error == null && state.profile == null) {
      return NikahBrowseScreen(restriction: NikahBrowseRestriction.noProfile(context));
    }

    // A profile that exists but isn't payment/verification-complete yet
    // gets the same teaser treatment — browse freely, just gated on any
    // real action. An incomplete WIZARD (profile.isComplete == false), or
    // one paused for not paying within its 7-day window, is different:
    // both need the member's full attention on a dedicated status card
    // (_ProfileStatusView below), not a background banner over browsing.
    if (state.error == null &&
        state.profile != null &&
        state.profile!.isComplete &&
        !state.profile!.isPausedForNonPayment) {
      final restriction = _restrictionFor(context, state.profile!);
      if (restriction != null) {
        return NikahBrowseScreen(restriction: restriction);
      }
    }

    final theme = ModuleThemes.forModule('nikah');
    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('💍 Nikah Matchmaking'), actions: const [WhatsappChannelAction()]),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(nikahControllerProvider.notifier).refresh(),
            child: state.error != null
                ? _ErrorView(
                    message: state.error!,
                    onRetry: () =>
                        ref.read(nikahControllerProvider.notifier).refresh(),
                  )
                : _ProfileStatusView(profile: state.profile!),
          ),
        ),
      ),
    );
  }

  NikahBrowseRestriction? _restrictionFor(BuildContext context, NikahProfile profile) {
    if (profile.paymentStatus == 'unpaid' || profile.paymentStatus == 'rejected') {
      return NikahBrowseRestriction.paymentPending(
        context,
        rejected: profile.paymentStatus == 'rejected',
        amount: profile.paymentAmount,
        daysRemaining: profile.paymentDeadlineDaysRemaining,
      );
    }
    if (profile.paymentStatus == 'submitted') {
      return NikahBrowseRestriction.paymentUnderReview(context);
    }
    if (profile.verificationStatus != 'verified') {
      return NikahBrowseRestriction.verificationPending(
        context,
        rejected: profile.verificationStatus == 'rejected',
        rejectionReason: profile.rejectionReason,
      );
    }
    return null;
  }
}

class _ProfileStatusView extends StatelessWidget {
  final NikahProfile profile;
  const _ProfileStatusView({required this.profile});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Checked ahead of !isComplete below — a paused member needs the
    // specific "extend or contact support" action, not the generic
    // "continue setup" card (this profile was already complete, or it
    // wouldn't have had a payment deadline running in the first place).
    if (profile.isPausedForNonPayment) {
      return _PausedForNonPaymentCard(profile: profile);
    }

    if (!profile.isComplete) {
      return _StatusCard(
        emoji: '📝',
        title: l10n.nikahFinishProfileTitle,
        message: l10n.nikahFinishProfileMessage(profile.completenessPercentage),
        actionLabel: l10n.nikahContinueSetup,
        onAction: () => context.push(_nextIncompleteStepRoute(profile)),
      );
    }

    // Payment/verification-pending states are handled by NikahHomeScreen
    // itself (restricted teaser browse) before this view is ever built —
    // reaching here with a complete profile means it's either still
    // mid-wizard (above) or fully verified and paid (below).

    // Fully verified and paid — the real hub.
    return _NikahHub(profile: profile);
  }
}

// A profile visibility switch — "hidden from search" isn't the same as
// admin suspension, see NikahSafetyController::toggleActive()'s own
// comment on that distinction; this just lets a member pause being
// discoverable without deleting anything.
// The 7-day-payment-window pause state — self-service "Extend 7 Days" (no
// admin approval, capped — see NikahProfile::MAX_PAYMENT_DEADLINE_EXTENSIONS
// on the backend) while extensions remain, then a WhatsApp support link
// once they're used up. Mirrors nikah/payment.blade.php's web version.
class _PausedForNonPaymentCard extends ConsumerStatefulWidget {
  final NikahProfile profile;
  const _PausedForNonPaymentCard({required this.profile});

  @override
  ConsumerState<_PausedForNonPaymentCard> createState() => _PausedForNonPaymentCardState();
}

class _PausedForNonPaymentCardState extends ConsumerState<_PausedForNonPaymentCard> {
  bool _busy = false;
  String? _error;

  Future<void> _extend() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(nikahControllerProvider.notifier).extendPaymentDeadline();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _contactSupport() async {
    final link = widget.profile.supportWhatsappLink;
    if (link == null) return;
    final uri = Uri.parse(link);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.profile.maxPaymentDeadlineExtensions - widget.profile.paymentDeadlineExtensionsUsed;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: Colors.amber.withValues(alpha: 0.15),
            child: const Text('⏸️', style: TextStyle(fontSize: 40)),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Your profile is paused',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'The 7-day window to complete your verification fee payment ran out, so your profile is hidden from search. Nothing is lost — it\'s all still saved.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ),
          const SizedBox(height: 16),
        ],
        if (widget.profile.canExtendPaymentDeadline) ...[
          ElevatedButton(
            onPressed: _busy ? null : _extend,
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Extend 7 Days'),
          ),
          const SizedBox(height: 8),
          Text(
            '$remaining self-service extension(s) left after this.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ] else ...[
          ElevatedButton.icon(
            onPressed: _contactSupport,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            icon: const Icon(Icons.chat_bubble, color: Colors.white),
            label: const Text('Contact Support on WhatsApp'),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ve used all your self-service extensions — our team can reactivate it for you.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ],
    );
  }
}

class _NikahHub extends ConsumerStatefulWidget {
  final NikahProfile profile;
  const _NikahHub({required this.profile});

  @override
  ConsumerState<_NikahHub> createState() => _NikahHubState();
}

class _NikahHubState extends ConsumerState<_NikahHub> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FirstVisitTour.showIfNeeded(context, storageKey: 'nikah_hub_tour_seen', steps: _nikahTourSteps);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profile = widget.profile;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('✅', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.nikahProfileLiveMessage,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => FirstVisitTour.show(context, steps: _nikahTourSteps),
            icon: const Text('❓'),
            label: const Text('How does this work?'),
          ),
        ),
        const SizedBox(height: 8),
        const _CounselorSection(),
        const SizedBox(height: 20),
        _HubTile(
          emoji: '🔎',
          title: l10n.nikahBrowseMatchesTitle,
          subtitle: l10n.nikahBrowseMatchesSubtitle,
          onTap: () => context.push('/nikah/browse'),
        ),
        _HubTile(
          emoji: '💌',
          title: l10n.nikahMyInterestsTitle,
          subtitle: l10n.nikahMyInterestsSubtitle,
          onTap: () => context.push('/nikah/interests'),
        ),
        _HubTile(
          emoji: '⭐',
          title: 'Saved Profiles',
          subtitle: 'Candidates you starred while browsing',
          onTap: () => context.push('/nikah/saved'),
        ),
        _HubTile(
          emoji: '⚙️',
          title: l10n.nikahEditProfileTitle,
          subtitle: l10n.nikahEditProfileSubtitle,
          onTap: () => context.push('/nikah/wizard/step1'),
        ),
        _HubTile(
          emoji: '🚫',
          title: 'Blocked Profiles',
          subtitle: 'Manage who you\'ve blocked',
          onTap: () => context.push('/nikah/blocked'),
        ),
        _ActiveToggleTile(isActive: profile.isActive),
        _HubTile(
          emoji: '❓',
          title: l10n.faqTitle,
          subtitle: l10n.nikahFaqsSubtitle,
          onTap: () => context.push('/faq/nikah'),
        ),
      ],
    );
  }
}

class _ActiveToggleTile extends ConsumerStatefulWidget {
  final bool isActive;
  const _ActiveToggleTile({required this.isActive});

  @override
  ConsumerState<_ActiveToggleTile> createState() => _ActiveToggleTileState();
}

class _ActiveToggleTileState extends ConsumerState<_ActiveToggleTile> {
  bool _busy = false;

  Future<void> _toggle() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(nikahRepositoryProvider);
      await repo.toggleActive();
      await ref.read(nikahControllerProvider.notifier).refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update visibility — try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: primary.withValues(alpha: 0.12),
          child: Text(
            widget.isActive ? '👁️' : '🙈',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          widget.isActive ? 'Visible in Search' : 'Hidden from Search',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          widget.isActive
              ? 'Other members can find your profile'
              : 'Your profile is paused',
        ),
        trailing: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Switch(value: widget.isActive, onChanged: (_) => _toggle()),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _HubTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: primary.withValues(alpha: 0.12),
          child: Text(emoji, style: const TextStyle(fontSize: 22)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusCard({
    required this.emoji,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: primary.withValues(alpha: 0.12),
            child: Text(emoji, style: const TextStyle(fontSize: 40)),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // ListView (not Center) so RefreshIndicator's pull-to-refresh gesture
    // still has something scrollable to grab, even on this error state.
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text('⚠️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onRetry,
                child: Text(l10n.nikahTryAgain),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Entirely optional bridge into the counselor-assisted flow — shows a
// "bring in a counselor" invitation until hired, then swaps to a status
// card once a Lead exists. Self-contained (own load/error state) so it
// doesn't complicate NikahHomeScreen's own profile-status loading above.
class _CounselorSection extends ConsumerStatefulWidget {
  const _CounselorSection();

  @override
  ConsumerState<_CounselorSection> createState() => _CounselorSectionState();
}

class _CounselorSectionState extends ConsumerState<_CounselorSection> {
  HiredLead? _lead;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(nikahHireRepositoryProvider);
      final lead = await repo.myLead();
      if (mounted) setState(() => _lead = lead);
    } catch (_) {
      // Non-fatal — the invitation card just shows as a fallback, same as
      // "not hired yet".
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    final primary = Theme.of(context).colorScheme.primary;
    final lead = _lead;

    if (lead == null) {
      return Card(
        color: primary.withValues(alpha: 0.06),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: primary.withValues(alpha: 0.15),
            child: const Text('🤝', style: TextStyle(fontSize: 20)),
          ),
          title: const Text(
            'Want hands-on help?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'Bring in a Nikah Counselor to search and guide you personally',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/nikah/counselor/pick'),
        ),
      );
    }

    final counselor = lead.counselor;
    final status = switch (lead.packagePaymentStatus) {
      null => 'Choose a package to get started',
      'submitted' => 'Payment under review',
      'rejected' =>
        lead.packagePaymentRejectionReason ?? 'Payment needs attention',
      _ => 'Active',
    };

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: primary.withValues(alpha: 0.12),
          backgroundImage: (counselor?.avatar ?? '').isNotEmpty
              ? NetworkImage(counselor!.avatar!)
              : null,
          child: (counselor?.avatar ?? '').isEmpty
              ? const Icon(Icons.person)
              : null,
        ),
        title: Text(
          counselor?.name ?? 'Your Nikah Counselor',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(status),
        trailing: IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: 'Message',
          onPressed: () => context.push('/nikah/counselor/chat/${lead.id}'),
        ),
        onTap: lead.packagePaymentStatus == null
            ? () => context.push('/nikah/counselor/package')
            : null,
      ),
    );
  }
}
