import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/image_pick_field.dart';
import '../../../shared/widgets/required_label.dart';
import '../data/nikah_hire_repository.dart';
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

  // Mirrors nikah/payment.blade.php on web: this screen is the single
  // choice point between the flat self-service fee and hiring a Nikah
  // Counselor. Once a Lead exists, the self-service card and the "hire a
  // counselor" CTA both disappear in favor of that Lead's package status.
  HiredLead? _lead;
  bool _loadingLead = true;
  bool _releasing = false;

  @override
  void initState() {
    super.initState();
    _loadLead();
  }

  Future<void> _loadLead() async {
    try {
      final lead = await ref.read(nikahHireRepositoryProvider).myLead();
      if (mounted) setState(() => _lead = lead);
    } catch (_) {
      // Non-fatal — falls back to showing the self-service flow only.
    } finally {
      if (mounted) setState(() => _loadingLead = false);
    }
  }

  Future<void> _release() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go back to self-service?'),
        content: const Text('This does not undo any payment already sent.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Go Back')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _releasing = true);
    try {
      await ref.read(nikahHireRepositoryProvider).release();
      await _loadLead();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Something went wrong. Please try again.')));
    } finally {
      if (mounted) setState(() => _releasing = false);
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 2)));
    }
  }

  Widget _copyableRow(String value, {TextStyle? style}) {
    return Row(
      children: [
        Expanded(child: Text(value, style: style)),
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
      return Theme(
        data: ModuleThemes.forModule('nikah'),
        child: Scaffold(
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
        ),
      );
    }

    if (_loadingLead) {
      return Theme(
        data: ModuleThemes.forModule('nikah'),
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (_lead != null) {
      return _buildHiredState(context, _lead!);
    }

    return Theme(
      data: ModuleThemes.forModule('nikah'),
      child: Scaffold(
      appBar: AppBar(title: const Text('Verification Fee')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                ErrorBanner(message: _error!),
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
                              children: [
                                Text('Account No: ', style: TextStyle(color: Colors.grey.shade700)),
                                Expanded(child: _copyableRow(profile.paymentInstructions.bankAccountNumber!, style: TextStyle(color: Colors.grey.shade700))),
                              ],
                            ),
                          if ((profile.paymentInstructions.bankAccountIban ?? '').isNotEmpty)
                            Row(
                              children: [
                                Text('IBAN: ', style: TextStyle(color: Colors.grey.shade700)),
                                Expanded(child: _copyableRow(profile.paymentInstructions.bankAccountIban!, style: TextStyle(color: Colors.grey.shade700))),
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
                decoration: InputDecoration(label: requiredLabel('Payment Method')),
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
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🤝 Prefer a dedicated Nikah Counselor?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 6),
                      Text(
                        'A consultant can search for matches, review proposals with you, and guide your family through the process instead.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () async {
                          await context.push('/nikah/counselor/pick');
                          _loadLead();
                        },
                        child: const Text('Browse Nikah Counselors'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildHiredState(BuildContext context, HiredLead lead) {
    final status = lead.packagePaymentStatus;
    final canRelease = status != 'submitted' && status != 'confirmed';

    return Theme(
      data: ModuleThemes.forModule('nikah'),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nikah Counselor'),
          actions: [
            if (canRelease)
              TextButton(
                onPressed: _releasing ? null : _release,
                child: _releasing
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Go Back'),
              ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Text('🤝', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Your Nikah Counselor', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                              Text(lead.counselor?.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (status == 'submitted')
                  _statusBanner('⏳ Your package payment has been submitted and is awaiting confirmation by our team.', Colors.orange)
                else if (status == 'confirmed')
                  _statusBanner('✅ Your package is active.', Colors.green)
                else ...[
                  if (status == 'rejected')
                    _statusBanner('❌ Your previous package payment was rejected. Reason: ${lead.packagePaymentRejectionReason ?? ''}', Colors.red),
                  if (status == 'rejected') const SizedBox(height: 12),
                  Text(
                    'Choose a package to get started with your counselor.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      await context.push('/nikah/counselor/package');
                      _loadLead();
                    },
                    child: const Text('Choose a Package'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBanner(String message, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(12)),
      child: Text(message, style: TextStyle(color: color.shade800, fontSize: 13)),
    );
  }
}
