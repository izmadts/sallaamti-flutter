import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/image_pick_field.dart';
import '../../../shared/widgets/required_label.dart';
import '../data/quran_live_repository.dart';

class QuranLiveSubscribeScreen extends ConsumerStatefulWidget {
  final int courseId;
  final int admissionId;
  const QuranLiveSubscribeScreen({super.key, required this.courseId, required this.admissionId});

  @override
  ConsumerState<QuranLiveSubscribeScreen> createState() => _QuranLiveSubscribeScreenState();
}

class _QuranLiveSubscribeScreenState extends ConsumerState<QuranLiveSubscribeScreen> {
  late Future<(QuranLiveSubscriptionInfo?, String, String, QuranLivePaymentInstructions)> _future;

  final _referenceController = TextEditingController();
  String _method = 'jazzcash';
  File? _screenshot;
  bool _busy = false;
  String? _error;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(quranLiveRepositoryProvider).subscription(widget.admissionId);
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 2)));
  }

  Widget _copyableRow(String value, {TextStyle? style}) {
    return Row(
      children: [
        Expanded(child: Text(value, style: style)),
        const SizedBox(width: 4),
        InkWell(
          onTap: () => _copy(value.replaceAll('-', '')),
          borderRadius: BorderRadius.circular(20),
          child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.copy, size: 16, color: Colors.grey)),
        ),
      ],
    );
  }

  // Gallery only — this is an existing screenshot, not a live identity
  // capture, so the camera is never offered here.
  Future<void> _pickScreenshot() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _screenshot = File(picked.path));
  }

  Future<void> _submit() async {
    if (_screenshot == null) {
      setState(() => _error = 'Please attach your payment screenshot.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(quranLiveRepositoryProvider).storeSubscription(
            admissionId: widget.admissionId,
            paymentMethod: _method,
            paymentReference: _referenceController.text.trim(),
            screenshot: _screenshot!,
          );
      setState(() => _submitted = true);
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('quran_live'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Monthly Fee')),
        body: SafeArea(
          child: _submitted ? _buildSubmitted(context) : _buildForm(context),
        ),
      ),
    );
  }

  Widget _buildSubmitted(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✅', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text('Payment Submitted', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Our team will confirm it shortly. Once confirmed, your teacher\'s daily class link will appear under My Class.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/quran-live/my-class'),
              child: const Text('Go to My Class'),
            ),
            TextButton(onPressed: () => context.go('/dashboard'), child: const Text('Back to Dashboard')),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return FutureBuilder<(QuranLiveSubscriptionInfo?, String, String, QuranLivePaymentInstructions)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final message = snapshot.error is ApiException ? (snapshot.error as ApiException).displayMessage : 'Something went wrong.';
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _future = ref.read(quranLiveRepositoryProvider).subscription(widget.admissionId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final (subscription, month, amount, instructions) = snapshot.data!;

        if (subscription != null && subscription.paymentStatus == 'submitted') {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⏳', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Awaiting Confirmation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Your payment for $month is under review.', style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[ErrorBanner(message: _error!), const SizedBox(height: 16)],
              if (subscription != null && subscription.paymentStatus == 'rejected') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Text('❌ ${subscription.paymentRejectionReason ?? ''}', style: TextStyle(color: Colors.red.shade700)),
                ),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fee for $month', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Rs. ${double.tryParse(amount)?.toStringAsFixed(0) ?? amount}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (instructions.hasAnyMethod)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Send payment to', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        if (instructions.hasJazzcash) ...[
                          const Text('📱 JazzCash', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          _copyableRow(instructions.jazzcashNumber!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          if ((instructions.jazzcashAccountTitle ?? '').isNotEmpty)
                            Text(instructions.jazzcashAccountTitle!, style: TextStyle(color: Colors.grey.shade600)),
                        ],
                        if (instructions.hasJazzcash && instructions.hasBankTransfer) const SizedBox(height: 16),
                        if (instructions.hasBankTransfer) ...[
                          const Text('🏦 Bank Transfer', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Bank: ${instructions.bankName}', style: TextStyle(color: Colors.grey.shade700)),
                          if ((instructions.bankAccountTitle ?? '').isNotEmpty) Text('Account Title: ${instructions.bankAccountTitle}', style: TextStyle(color: Colors.grey.shade700)),
                          if ((instructions.bankAccountNumber ?? '').isNotEmpty)
                            Row(children: [Text('Account No: ', style: TextStyle(color: Colors.grey.shade700)), Expanded(child: _copyableRow(instructions.bankAccountNumber!, style: TextStyle(color: Colors.grey.shade700)))]),
                          if ((instructions.bankAccountIban ?? '').isNotEmpty)
                            Row(children: [Text('IBAN: ', style: TextStyle(color: Colors.grey.shade700)), Expanded(child: _copyableRow(instructions.bankAccountIban!, style: TextStyle(color: Colors.grey.shade700)))]),
                        ],
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Payment details have not been configured yet. Please contact support before sending any payment.', style: TextStyle(color: Colors.deepOrange)),
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
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(labelText: 'Transaction Reference (optional)'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 160,
                child: ImagePickField(label: 'Screenshot', file: _screenshot, alreadyUploaded: false, onTap: _pickScreenshot),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Payment'),
              ),
            ],
          ),
        );
      },
    );
  }
}
