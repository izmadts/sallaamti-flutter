import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../features/auth/data/social_auth_service.dart';
import '../../features/auth/state/auth_controller.dart';
import '../../l10n/generated/app_localizations.dart';

// Shared by the login and register screens — signing in with Google or
// Facebook is the same account (an app account is a web account either
// way), so there's no separate "register with Google" flow to duplicate.
class SocialSignInButtons extends ConsumerStatefulWidget {
  const SocialSignInButtons({super.key});

  @override
  ConsumerState<SocialSignInButtons> createState() => _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends ConsumerState<SocialSignInButtons> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      if (mounted) _showError(AppLocalizations.of(context)!.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(l10n.orContinueWith, style: TextStyle(color: Colors.grey.shade600)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    final token = await SocialAuthService.signInWithGoogle();
                    if (token != null) {
                      await ref.read(authControllerProvider.notifier).socialGoogle(token);
                    }
                  }),
          icon: const Text('🇬', style: TextStyle(fontSize: 18)),
          label: Text(l10n.continueWithGoogle),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    final token = await SocialAuthService.signInWithFacebook();
                    if (token != null) {
                      await ref.read(authControllerProvider.notifier).socialFacebook(token);
                    }
                  }),
          icon: const Text('🇫', style: TextStyle(fontSize: 18)),
          label: Text(l10n.continueWithFacebook),
        ),
        if (_busy) const Padding(
          padding: EdgeInsets.only(top: 16),
          child: CircularProgressIndicator(),
        ),
      ],
    );
  }
}
