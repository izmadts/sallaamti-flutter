import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/module_themes.dart';
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
                  child: state.profile == null
                      ? _NoProfileView()
                      : _ProfileStatusView(profile: state.profile!),
                ),
        ),
      ),
    );
  }
}

class _NoProfileView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Center(child: Text('💍', style: TextStyle(fontSize: 64))),
        const SizedBox(height: 20),
        const Text(
          'Find your match, the halal way',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Create your Nikah profile in a few short steps. Your guardian and identity verification keep the community safe and genuine.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: () => context.push('/nikah/wizard/step1'),
          child: const Text('Create Your Profile'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.push('/faq/nikah'),
          child: const Text('Frequently Asked Questions'),
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
    if (!profile.isComplete) {
      return _StatusCard(
        emoji: '📝',
        title: 'Finish setting up your profile',
        message: '${profile.completenessPercentage}% complete — a few more details and your CNIC are needed before you can submit.',
        actionLabel: 'Continue Setup',
        onAction: () => context.push('/nikah/wizard/step2'),
      );
    }

    if (profile.paymentStatus == 'unpaid' || profile.paymentStatus == 'rejected') {
      return _StatusCard(
        emoji: '💳',
        title: profile.paymentStatus == 'rejected' ? 'Payment needs another look' : 'One step left — the verification fee',
        message: profile.paymentStatus == 'rejected'
            ? 'Your last payment proof wasn\'t accepted. Please submit it again.'
            : 'Pay a one-time Rs. ${profile.paymentAmount ?? ''} verification fee to get your profile reviewed.',
        actionLabel: 'Pay Verification Fee',
        onAction: () => context.push('/nikah/payment'),
      );
    }

    if (profile.paymentStatus == 'submitted') {
      return _StatusCard(
        emoji: '⏳',
        title: 'Payment under review',
        message: 'We\'re confirming your payment — this usually takes a short while.',
      );
    }

    if (profile.verificationStatus != 'verified') {
      return _StatusCard(
        emoji: '🔍',
        title: 'Profile under verification',
        message: profile.verificationStatus == 'rejected'
            ? (profile.rejectionReason ?? 'Your profile needs some changes — please update your details.')
            : 'Our team is reviewing your details and CNIC. You\'ll be notified once approved.',
        actionLabel: profile.verificationStatus == 'rejected' ? 'Update Profile' : null,
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
          child: const Row(
            children: [
              Text('✅', style: TextStyle(fontSize: 24)),
              SizedBox(width: 12),
              Expanded(child: Text('Your profile is live and verified!', style: TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _HubTile(
          emoji: '🔎',
          title: 'Browse Matches',
          subtitle: 'See profiles that match your preferences',
          onTap: () => context.push('/nikah/browse'),
        ),
        _HubTile(
          emoji: '💌',
          title: 'My Interests',
          subtitle: 'Sent and received interest requests',
          onTap: () => context.push('/nikah/interests'),
        ),
        _HubTile(
          emoji: '⚙️',
          title: 'Edit My Profile',
          subtitle: 'Update your details anytime',
          onTap: () => context.push('/nikah/wizard/step1'),
        ),
        _HubTile(
          emoji: '❓',
          title: 'FAQs',
          subtitle: 'Common questions about Nikah matching',
          onTap: () => context.push('/faq/nikah'),
        ),
      ],
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Text(emoji, style: const TextStyle(fontSize: 28)),
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
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Center(child: Text(emoji, style: const TextStyle(fontSize: 56))),
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
