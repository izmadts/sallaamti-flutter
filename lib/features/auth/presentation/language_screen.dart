import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/locale_controller.dart';

// First screen a brand-new user ever sees — big, icon-forward, two taps
// max, so a low-literacy visitor never has to read English to get past it.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🌍', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                'Choose your language\nاپنی زبان منتخب کریں',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.5),
              ),
              const SizedBox(height: 40),
              _LanguageCard(
                label: 'English',
                emoji: '🇬🇧',
                onTap: () => _choose(context, ref, 'en'),
              ),
              const SizedBox(height: 16),
              _LanguageCard(
                label: 'اردو',
                emoji: '🇵🇰',
                onTap: () => _choose(context, ref, 'ur'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _choose(BuildContext context, WidgetRef ref, String code) async {
    await ref.read(localeControllerProvider.notifier).choose(code);
    if (context.mounted) context.go('/welcome');
  }
}

class _LanguageCard extends StatelessWidget {
  final String label;
  final String emoji;
  final VoidCallback onTap;

  const _LanguageCard({required this.label, required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
