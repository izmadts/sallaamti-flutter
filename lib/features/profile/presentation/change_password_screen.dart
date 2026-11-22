import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/password_field.dart';
import '../../auth/state/auth_controller.dart';
import '../data/profile_repository.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  // True when the client is here because a Nikah Counselor set a temporary
  // password for them (User::must_change_password) — shows a short
  // explanation and hides the back button so they land somewhere useful
  // either way, instead of bouncing back to a bare dialog.
  final bool isForced;
  const ChangePasswordScreen({super.key, this.isForced = false});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _hasRealPassword => ref.read(authControllerProvider).user?.hasRealPassword ?? true;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_newController.text != _confirmController.text) {
      setState(() => _error = l10n.passwordsDoNotMatchError);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await ref.read(profileRepositoryProvider).updatePassword(
            currentPassword: _hasRealPassword ? _currentController.text : null,
            password: _newController.text,
          );
      ref.read(authControllerProvider.notifier).setUser(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordUpdatedMessage)));
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !widget.isForced,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.changePasswordLabel),
          automaticallyImplyLeading: !widget.isForced,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (widget.isForced) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    _hasRealPassword ? l10n.tempPasswordNoticeMessage : l10n.setPasswordNoticeMessage,
                    style: const TextStyle(color: Colors.blueGrey),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                        child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_hasRealPassword) ...[
                      PasswordField(
                        controller: _currentController,
                        labelText: l10n.currentPasswordLabel,
                        validator: (v) => (v == null || v.isEmpty) ? l10n.enterCurrentPasswordError : null,
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      Text(
                        l10n.noPasswordYetMessage,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                    ],
                    PasswordField(
                      controller: _newController,
                      labelText: l10n.newPasswordLabel,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) => (v == null || v.length < 8) ? l10n.atLeast8CharsError : null,
                    ),
                    const SizedBox(height: 12),
                    PasswordField(
                      controller: _confirmController,
                      labelText: l10n.confirmNewPasswordLabel,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) => (v == null || v.isEmpty) ? l10n.confirmNewPasswordError : null,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(l10n.updatePasswordButton),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
