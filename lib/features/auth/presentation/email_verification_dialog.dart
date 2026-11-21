import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/error_banner.dart';
import '../state/auth_controller.dart';

// Popped automatically the moment any API call 403s with code
// 'email_not_verified' (see EmailVerificationGate) — found live (16 Nov
// 2026): the server-side block already existed, but nowhere in the app,
// once already logged in, actually had a code-entry field to act on it;
// the member just saw prose telling them to do something with no way to
// do it. This is reachable the instant it's needed, from any screen.
class EmailVerificationDialog extends ConsumerStatefulWidget {
  const EmailVerificationDialog({super.key});

  @override
  ConsumerState<EmailVerificationDialog> createState() => _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends ConsumerState<EmailVerificationDialog> {
  final _codeController = TextEditingController();
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context)!;
    if (_codeController.text.trim().length != 6) {
      setState(() => _error = l10n.fieldRequired);
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final user = await ref.read(authRepositoryProvider).verifyEmailCode(_codeController.text.trim());
      ref.read(authControllerProvider.notifier).setUser(user);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.emailVerifiedSuccess)));
      }
    } on ApiException catch (e) {
      setState(() => _error = e.firstErrorFor('code') ?? e.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _resending = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).resendEmailVerificationCode();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.emailVerificationCodeSent)));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.emailVerificationDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.emailVerificationDialogMessage),
          const SizedBox(height: 16),
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(labelText: '••••••'),
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _resending ? null : _resend,
          child: _resending
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.resendCode),
        ),
        FilledButton(
          onPressed: _verifying ? null : _verify,
          child: _verifying
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(l10n.verify),
        ),
      ],
    );
  }
}
