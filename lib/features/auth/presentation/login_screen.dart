import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/password_field.dart';
import '../../../shared/widgets/social_sign_in_buttons.dart';
import '../state/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _generalError;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _generalError = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(
            login: _loginController.text.trim(),
            password: _passwordController.text,
          );
      // Tells the OS password manager the credentials just used were
      // real/valid, which is what actually triggers its "Save password?"
      // prompt — it won't offer that on every keystroke, only here.
      TextInput.finishAutofillContext();
    } on ApiException catch (e) {
      setState(() => _generalError = e.firstErrorFor('login') ?? e.message);
    } catch (_) {
      setState(() => _generalError = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      child: const Text('👋', style: TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_generalError != null) ...[
                    ErrorBanner(message: _generalError!),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _loginController,
                    decoration: InputDecoration(
                      labelText: '${l10n.emailAddress} / ${l10n.phoneNumber}',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.email,
                      AutofillHints.username,
                    ],
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.fieldRequired
                        : null,
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _passwordController,
                    labelText: l10n.password,
                    autofillHints: const [AutofillHints.password],
                    validator: (v) =>
                        (v == null || v.isEmpty) ? l10n.fieldRequired : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.loginButton),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: Text(l10n.dontHaveAccount),
                  ),
                  const SizedBox(height: 8),
                  const SocialSignInButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
