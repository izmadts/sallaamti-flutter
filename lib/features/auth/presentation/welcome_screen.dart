import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Text('🕊️', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                l10n.welcomeTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.welcomeSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => context.go('/register'),
                child: Text(l10n.registerTitle),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/login'),
                child: Text(l10n.loginTitle),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/otp'),
                child: Text(l10n.signInWithCode),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
