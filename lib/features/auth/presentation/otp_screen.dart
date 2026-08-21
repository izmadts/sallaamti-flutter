import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../state/auth_controller.dart';

// Two short steps rather than one dense form — deliberately mirrors the
// "one idea per screen" brief. Step 1 collects just enough to send a code;
// step 2 is only ever the 6-digit code.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  int _step = 0;
  bool _submitting = false;
  String? _error;
  String? _purpose;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final purpose = await ref.read(authControllerProvider.notifier).requestOtp(
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim(),
            name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
          );
      setState(() {
        _purpose = purpose;
        _step = 1;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _verifyCode() async {
    final l10n = AppLocalizations.of(context)!;
    if (_codeController.text.trim().length != 6) {
      setState(() => _error = l10n.fieldRequired);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).verifyOtp(
            phone: _phoneController.text.trim(),
            code: _codeController.text.trim(),
            email: _emailController.text.trim(),
            name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
          );
    } on ApiException catch (e) {
      setState(() => _error = e.firstErrorFor('code') ?? e.message);
    } catch (_) {
      setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.otpTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
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
                if (_step == 0) ..._requestStepFields(l10n) else ..._verifyStepFields(l10n),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : (_step == 0 ? _requestCode : _verifyCode),
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_step == 0 ? l10n.sendCode : l10n.verify),
                ),
                if (_step == 1) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _submitting ? null : _requestCode,
                    child: Text(l10n.resendCode),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _requestStepFields(AppLocalizations l10n) => [
        TextFormField(
          controller: _phoneController,
          decoration: InputDecoration(labelText: l10n.phoneNumber),
          keyboardType: TextInputType.phone,
          validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(labelText: l10n.emailAddress),
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
            if (!v.contains('@')) return l10n.invalidEmail;
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(labelText: '${l10n.fullName} (${l10n.registerTitle})'),
        ),
      ];

  List<Widget> _verifyStepFields(AppLocalizations l10n) => [
        Text(l10n.otpSentTo(_phoneController.text.trim()), style: const TextStyle(fontSize: 15)),
        if (_purpose == 'registration') ...[
          const SizedBox(height: 4),
          Text(l10n.registerTitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _codeController,
          decoration: const InputDecoration(labelText: '••••••'),
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.w700),
        ),
      ];
}
