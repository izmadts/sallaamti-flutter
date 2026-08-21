import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/language_switch_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // Matches the logo artwork's own background and the native splash
      // screen, so onboarding reads as one continuous brand moment rather
      // than a jarring color cut.
      backgroundColor: AppTheme.logoBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Image.asset('assets/app-logo.png', height: 30),
        actions: const [LanguageSwitchButton()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Image.asset('assets/icon.png', width: 220),
              const SizedBox(height: 20),
              Text(
                l10n.welcomeTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.welcomeSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade400),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => context.go('/register'),
                child: Text(l10n.registerTitle),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 1.5),
                ),
                onPressed: () => context.go('/login'),
                child: Text(l10n.loginTitle),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/otp'),
                child: Text(l10n.signInWithCode, style: const TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
