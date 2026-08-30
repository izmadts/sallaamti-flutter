import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/nikah_hire_repository.dart';
import '../domain/nikah_profile.dart';
import '../state/nikah_controller.dart';

class NikahHomeScreen extends ConsumerWidget {
  const NikahHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nikahControllerProvider);
    final theme = ModuleThemes.forModule('nikah');

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('💍 Nikah Matchmaking')),
        body: SafeArea(
          child: state.status == NikahLoadStatus.loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => ref.read(nikahControllerProvider.notifier).refresh(),
                  child: state.error != null
                      ? _ErrorView(message: state.error!, onRetry: () => ref.read(nikahControllerProvider.notifier).refresh())
                      : state.profile == null
                          ? const _NoProfileView()
                          : _ProfileStatusView(profile: state.profile!),
                ),
        ),
      ),
    );
  }
}

class _NoProfileView extends StatelessWidget {
  const _NoProfileView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Center(child: Text('💍', style: TextStyle(fontSize: 64))),
        const SizedBox(height: 20),
        Text(
          l10n.nikahFindMatchTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.nikahFindMatchSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: () => context.push('/nikah/wizard/step1'),
          child: Text(l10n.nikahCreateProfile),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.push('/faq/nikah'),
          child: Text(l10n.faqTitle),
        ),
      ],
    );
  }
}

class _ProfileStatusView extends StatelessWidget {
  final NikahProfile profile;
  const _ProfileStatusView({required this.profile});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!profile.isComplete) {
      return _StatusCard(
        emoji: '📝',
        title: l10n.nikahFinishProfileTitle,
        message: l10n.nikahFinishProfileMessage(profile.completenessPercentage),
        actionLabel: l10n.nikahContinueSetup,
        onAction: () => context.push('/nikah/wizard/step2'),
      );
    }

    if (profile.paymentStatus == 'unpaid' || profile.paymentStatus == 'rejected') {
      return _StatusCard(
        emoji: '💳',
        title: profile.paymentStatus == 'rejected' ? l10n.nikahPaymentRejectedTitle : l10n.nikahPaymentDueTitle,
        message: profile.paymentStatus == 'rejected'
            ? l10n.nikahPaymentRejectedMessage
            : l10n.nikahPaymentDueMessage(profile.paymentAmount ?? ''),
        actionLabel: l10n.nikahPayVerificationFee,
        onAction: () => context.push('/nikah/payment'),
      );
    }

    if (profile.paymentStatus == 'submitted') {
      return _StatusCard(
        emoji: '⏳',
        title: l10n.nikahPaymentUnderReviewTitle,
        message: l10n.nikahPaymentUnderReviewMessage,
      );
    }

    if (profile.verificationStatus != 'verified') {
      return _StatusCard(
        emoji: '🔍',
        title: l10n.nikahProfileUnderVerificationTitle,
        message: profile.verificationStatus == 'rejected'
            ? (profile.rejectionReason ?? l10n.nikahProfileNeedsChangesMessage)
            : l10n.nikahProfileReviewingMessage,
        actionLabel: profile.verificationStatus == 'rejected' ? l10n.nikahUpdateProfile : null,
        onAction: profile.verificationStatus == 'rejected' ? () => context.push('/nikah/wizard/step1') : null,
      );
    }

    // Fully verified and paid — the real hub.
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
              Expanded(child: Text(l10n.nikahProfileLiveMessage, style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
        ),
        const SizedBox(height: 20),
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

// A profile visibility switch — "hidden from search" isn't the same as
// admin suspension, see NikahSafetyController::toggleActive()'s own
// comment on that distinction; this just lets a member pause being
// discoverable without deleting anything.
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update visibility — try again.')));
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
          child: Text(widget.isActive ? '👁️' : '🙈', style: const TextStyle(fontSize: 20)),
        ),
        title: Text(widget.isActive ? 'Visible in Search' : 'Hidden from Search', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(widget.isActive ? 'Other members can find your profile' : 'Your profile is paused'),
        trailing: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Switch(value: widget.isActive, onChanged: (_) => _toggle()),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _HubTile({required this.emoji, required this.title, required this.subtitle, required this.onTap});

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
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
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
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onRetry, child: Text(l10n.nikahTryAgain)),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(radius: 22, backgroundColor: primary.withValues(alpha: 0.15), child: const Text('🤝', style: TextStyle(fontSize: 20))),
          title: const Text('Want hands-on help?', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Bring in a Nikah Counselor to search and guide you personally'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/nikah/counselor/pick'),
        ),
      );
    }

    final counselor = lead.counselor;
    final status = switch (lead.packagePaymentStatus) {
      null => 'Choose a package to get started',
      'submitted' => 'Payment under review',
      'rejected' => lead.packagePaymentRejectionReason ?? 'Payment needs attention',
      _ => 'Active',
    };

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: primary.withValues(alpha: 0.12),
          backgroundImage: (counselor?.avatar ?? '').isNotEmpty ? NetworkImage(counselor!.avatar!) : null,
          child: (counselor?.avatar ?? '').isEmpty ? const Icon(Icons.person) : null,
        ),
        title: Text(counselor?.name ?? 'Your Nikah Counselor', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(status),
        trailing: IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: 'Message',
          onPressed: () => context.push('/nikah/counselor/chat/${lead.id}'),
        ),
        onTap: lead.packagePaymentStatus == null ? () => context.push('/nikah/counselor/package') : null,
      ),
    );
  }
}
