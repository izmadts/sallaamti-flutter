import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/module_themes.dart';

// The single "Quran" entry point from the dashboard — it fronts two
// genuinely separate backend systems (QuranLiveCourse's admission/
// subscription/group-class model vs the self-paced Course/Lesson model
// shared with Digital Skills), so rather than give each its own dashboard
// tile, one tap here lets the member pick which kind of learning they want.
class QuranHubScreen extends StatelessWidget {
  const QuranHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('quran'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Quran Learning')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('How would you like to learn?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Pick whichever fits you best — you can do both.', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 24),
                _HubOptionCard(
                  emoji: '🕌',
                  color: const Color(0xFF1D5FB8),
                  title: 'Live Quran Classes',
                  subtitle: 'Learn face-to-face with a qualified teacher over live video — small groups, monthly subscription.',
                  onTap: () => context.push('/quran-live'),
                ),
                const SizedBox(height: 16),
                _HubOptionCard(
                  emoji: '📖',
                  color: const Color(0xFF0D6B6B),
                  title: 'Self-Paced Learning',
                  subtitle: 'Go through recorded lessons at your own pace, whenever suits you.',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon'))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HubOptionCard extends StatelessWidget {
  final String emoji;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubOptionCard({required this.emoji, required this.color, required this.title, required this.subtitle, required this.onTap});

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
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
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
                    Text(subtitle, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.3)),
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
