import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/password_field.dart';
import '../state/auth_controller.dart';

// Two steps on one screen: ask for the email, then take the emailed code and
// the new password. Keeping them together means the address stays on screen
// while the code is typed, and "wrong email?" is a step back rather than a
// re-navigation.
//
// A successful reset signs the member in, so this ends on the dashboard —
// making them log in again with a password they just chose would be busywork.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _codeSent = false;
  bool _submitting = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();

  Future<void> _sendCode() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
      _notice = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).forgotPassword(_email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _notice = l10n.resetCodeSentTo(_email);
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _reset() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_resetFormKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).resetPassword(
            email: _email,
            code: _codeController.text.trim(),
            password: _passwordController.text,
          );
      // The router's redirect sends an authenticated user to the dashboard on
      // its own; nothing to navigate to here.
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.firstErrorFor('code') ?? e.firstErrorFor('password') ?? e.displayMessage);
      }
    } catch (_) {
      if (mounted) setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.forgotPasswordTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  child: const Text('🔑', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.forgotPasswordIntro,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: 16),
              ],
              if (_notice != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.mark_email_read_outlined, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_notice!, style: TextStyle(color: Colors.green.shade800, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (!_codeSent) _emailStep(l10n) else _resetStep(l10n),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _submitting ? null : () => context.go('/login'),
                child: Text(l10n.backToLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emailStep(AppLocalizations l10n) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(labelText: l10n.emailAddress),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return l10n.fieldRequired;
              if (!value.contains('@') || !value.contains('.')) return l10n.invalidEmail;
              return null;
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submitting ? null : _sendCode,
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(l10n.sendResetCode),
          ),
        ],
      ),
    );
  }

  Widget _resetStep(AppLocalizations l10n) {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _codeController,
            decoration: InputDecoration(labelText: l10n.resetCode, counterText: ''),
            keyboardType: TextInputType.number,
            maxLength: 6,
            validator: (v) => (v ?? '').trim().length != 6 ? l10n.fieldRequired : null,
          ),
          const SizedBox(height: 16),
          PasswordField(
            controller: _passwordController,
            labelText: l10n.newPassword,
            autofillHints: const [AutofillHints.newPassword],
            validator: (v) {
              if ((v ?? '').isEmpty) return l10n.fieldRequired;
              // Mirrors Laravel's Password::defaults() minimum, so an
              // obviously-too-short password is caught before the round trip.
              if (v!.length < 8) return l10n.passwordTooShort;
              return null;
            },
          ),
          const SizedBox(height: 16),
          PasswordField(
            controller: _confirmController,
            labelText: l10n.confirmPassword,
            autofillHints: const [AutofillHints.newPassword],
            validator: (v) => v != _passwordController.text ? l10n.passwordsDoNotMatch : null,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submitting ? null : _reset,
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(l10n.resetPasswordButton),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                          _codeSent = false;
                          _notice = null;
                          _error = null;
                          _codeController.clear();
                        }),
                child: Text(l10n.useADifferentEmail),
              ),
              TextButton(
                onPressed: _submitting ? null : _sendCode,
                child: Text(l10n.resendCode),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
