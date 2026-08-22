import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/image_pick_field.dart';
import '../state/nikah_controller.dart';

class NikahPaymentScreen extends ConsumerStatefulWidget {
  const NikahPaymentScreen({super.key});

  @override
  ConsumerState<NikahPaymentScreen> createState() => _NikahPaymentScreenState();
}

class _NikahPaymentScreenState extends ConsumerState<NikahPaymentScreen> {
  String _method = 'jazzcash';
  File? _screenshot;
  bool _busy = false;
  String? _error;
  bool _submitted = false;

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 2)));
    }
  }

  Widget _copyableRow(String value, {TextStyle? style}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: style),
        const SizedBox(width: 4),
        InkWell(
          // Copy the plain digits only — dashes are display formatting, and
          // most payment apps' "enter account number" fields choke on them.
          onTap: () => _copy(value.replaceAll('-', '')),
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.copy, size: 16, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Future<void> _pickScreenshot() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _screenshot = File(picked.path));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_screenshot == null) {
      setState(() => _error = l10n.nikahPaymentScreenshotRequired);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final repo = ref.read(nikahRepositoryProvider);
      await repo.submitPayment(paymentMethod: _method, paymentReference: '', screenshot: _screenshot!);
      // submitPayment() goes through the repository directly, not the
      // controller, so the cached profile in nikahControllerProvider still
      // shows the pre-submission payment_status — refresh it now so the
      // home screen shows "waiting for approval" instead of the stale
      // "pay now" prompt when the user taps back.
      await ref.read(nikahControllerProvider.notifier).refresh();
      setState(() => _submitted = true);
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(nikahControllerProvider).profile;
    final l10n = AppLocalizations.of(context)!;

    if (_submitted) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.nikahPaymentSubmittedTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✅', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                Text(l10n.nikahPaymentSubmittedTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Our team will confirm it shortly, then your profile can go live once it\'s also verified.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/nikah'),
                  child: Text(l10n.nikahBackToNikah),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Verification Fee')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('One-time verification fee', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        'Rs. ${profile?.paymentAmount ?? '—'}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pay via JazzCash or bank transfer, then upload a screenshot as proof. Our team confirms it manually.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (profile != null && profile.paymentInstructions.hasAnyMethod)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Send payment to', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        if (profile.paymentInstructions.hasJazzcash) ...[
                          const Text('📱 JazzCash', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          _copyableRow(profile.paymentInstructions.jazzcashNumber!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          if ((profile.paymentInstructions.jazzcashAccountTitle ?? '').isNotEmpty)
                            Text(profile.paymentInstructions.jazzcashAccountTitle!, style: TextStyle(color: Colors.grey.shade600)),
                        ],
                        if (profile.paymentInstructions.hasJazzcash && profile.paymentInstructions.hasBankTransfer) const SizedBox(height: 16),
                        if (profile.paymentInstructions.hasBankTransfer) ...[
                          const Text('🏦 Bank Transfer', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Bank: ${profile.paymentInstructions.bankName}', style: TextStyle(color: Colors.grey.shade700)),
                          if ((profile.paymentInstructions.bankAccountTitle ?? '').isNotEmpty)
                            Text('Account Title: ${profile.paymentInstructions.bankAccountTitle}', style: TextStyle(color: Colors.grey.shade700)),
                          if ((profile.paymentInstructions.bankAccountNumber ?? '').isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Account No: ', style: TextStyle(color: Colors.grey.shade700)),
                                _copyableRow(profile.paymentInstructions.bankAccountNumber!, style: TextStyle(color: Colors.grey.shade700)),
                              ],
                            ),
                          if ((profile.paymentInstructions.bankAccountIban ?? '').isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('IBAN: ', style: TextStyle(color: Colors.grey.shade700)),
                                _copyableRow(profile.paymentInstructions.bankAccountIban!, style: TextStyle(color: Colors.grey.shade700)),
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    'Payment details have not been configured yet. Please contact support before sending any payment.',
                    style: TextStyle(color: Colors.deepOrange),
                  ),
                ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                items: const [
                  DropdownMenuItem(value: 'jazzcash', child: Text('JazzCash')),
                  DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                ],
                onChanged: (v) => setState(() => _method = v!),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 160,
                child: ImagePickField(
                  label: 'Payment Screenshot',
                  file: _screenshot,
                  alreadyUploaded: false,
                  onTap: _pickScreenshot,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l10n.nikahSubmitPaymentProof),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
