import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/module_themes.dart';

// One entry point for the three reading/writing surfaces that used to be
// web-only: the Sallaamti blog, member-written posts, and testimonials.
// They're grouped rather than given three dashboard tiles of their own —
// each is light on its own, and together they read as "the community".
class CommunityHubScreen extends StatelessWidget {
  const CommunityHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('community'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Community')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Read, write, and share',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Articles from the Sallaamti team, posts written by members, and stories from people we\'ve helped.',
                style: TextStyle(color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 22),
              _HubCard(
                emoji: '📰',
                color: const Color(0xFF1D5FB8),
                title: 'Blog',
                subtitle: 'Articles and guidance from the Sallaamti team.',
                onTap: () => context.push('/community/blog'),
              ),
              const SizedBox(height: 14),
              _HubCard(
                emoji: '✍️',
                color: const Color(0xFF0D6B6B),
                title: 'Member Posts',
                subtitle: 'Read what other members have written — or publish something of your own.',
                onTap: () => context.push('/community/posts'),
              ),
              const SizedBox(height: 14),
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
