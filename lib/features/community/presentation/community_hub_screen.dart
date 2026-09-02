import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/module_themes.dart';
import '../../auth/state/auth_controller.dart';

// Testimonials are open to every member. Member Posts (long-form articles
// with a review queue on the web) is gated to accounts with posts.manage or
// admin (AppUser.canWritePosts) — a common member's own posting surface in
// this app is the Wall, not this. Blog was dropped from the app entirely.
class CommunityHubScreen extends ConsumerWidget {
  const CommunityHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canWritePosts = ref.watch(authControllerProvider).user?.canWritePosts ?? false;

    return Theme(
      data: ModuleThemes.forModule('community'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Community')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Share and be heard',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Stories from people we\'ve helped — share yours if Sallaamti has made a difference for you.',
                style: TextStyle(color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 22),
              if (canWritePosts) ...[
                _HubCard(
                  emoji: '✍️',
                  color: const Color(0xFF0D6B6B),
                  title: 'Member Posts',
                  subtitle: 'Read what other members have written — or publish something of your own.',
                  onTap: () => context.push('/community/posts'),
                ),
                const SizedBox(height: 14),
              ],
              _HubCard(
                emoji: '💬',
                color: const Color(0xFFB8962E),
                title: 'Testimonials',
                subtitle: 'Stories from the community. Share yours if Sallaamti has helped you.',
                onTap: () => context.push('/community/testimonials'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final String emoji;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubCard({
    required this.emoji,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
