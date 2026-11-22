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
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.nikahCopiedToClipboard), duration: const Duration(seconds: 2)));
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
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1280, maxHeight: 1280);
    if (picked != null) setState(() => _screenshot = File(picked.path));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_screenshot == null) {
      setState(() => _error = l10n.quranLiveAttachScreenshotError);
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
      setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Theme(
      data: ModuleThemes.forModule('quran_live'),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.quranLiveMonthlyFeeTitle)),
        body: SafeArea(
          child: _submitted ? _buildSubmitted(context) : _buildForm(context),
        ),
      ),
    );
  }

  Widget _buildSubmitted(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✅', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(l10n.quranLivePaymentSubmittedTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              l10n.quranLivePaymentSubmittedMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/quran-live/my-class'),
              child: Text(l10n.quranLiveGoToMyClassButton),
            ),
            TextButton(onPressed: () => context.go('/dashboard'), child: Text(l10n.backToDashboardButton)),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<(QuranLiveSubscriptionInfo?, String, String, QuranLivePaymentInstructions)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final message = snapshot.error is ApiException ? (snapshot.error as ApiException).displayMessage : l10n.quranLiveSomethingWentWrong;
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
                    child: Text(l10n.retryLabel),
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
                  Text(l10n.quranLiveAwaitingConfirmationTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(l10n.quranLivePaymentUnderReviewForMonth(month), style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
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
                      Text(l10n.quranLiveFeeForMonthLabel(month), style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(l10n.nikahFeeAmount(double.tryParse(amount)?.toStringAsFixed(0) ?? amount), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
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
                        Text(l10n.nikahSendPaymentTo, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        if (instructions.hasJazzcash) ...[
                          Text(l10n.nikahJazzcashLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          _copyableRow(instructions.jazzcashNumber!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          if ((instructions.jazzcashAccountTitle ?? '').isNotEmpty)
                            Text(instructions.jazzcashAccountTitle!, style: TextStyle(color: Colors.grey.shade600)),
                        ],
                        if (instructions.hasJazzcash && instructions.hasBankTransfer) const SizedBox(height: 16),
                        if (instructions.hasBankTransfer) ...[
                          Text(l10n.nikahBankTransferLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(l10n.nikahBankLabel(instructions.bankName ?? ''), style: TextStyle(color: Colors.grey.shade700)),
                          if ((instructions.bankAccountTitle ?? '').isNotEmpty) Text(l10n.nikahAccountTitleLabel(instructions.bankAccountTitle ?? ''), style: TextStyle(color: Colors.grey.shade700)),
                          if ((instructions.bankAccountNumber ?? '').isNotEmpty)
                            Row(children: [Text(l10n.nikahAccountNoLabel, style: TextStyle(color: Colors.grey.shade700)), Expanded(child: _copyableRow(instructions.bankAccountNumber!, style: TextStyle(color: Colors.grey.shade700)))]),
                          if ((instructions.bankAccountIban ?? '').isNotEmpty)
                            Row(children: [Text(l10n.nikahIbanLabel, style: TextStyle(color: Colors.grey.shade700)), Expanded(child: _copyableRow(instructions.bankAccountIban!, style: TextStyle(color: Colors.grey.shade700)))]),
                        ],
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Text(l10n.nikahPaymentNotConfiguredMessage, style: const TextStyle(color: Colors.deepOrange)),
                ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: InputDecoration(label: requiredLabel(l10n.paymentMethodLabel)),
                items: [
                  DropdownMenuItem(value: 'jazzcash', child: Text(l10n.jazzcashMethodLabel)),
                  DropdownMenuItem(value: 'bank_transfer', child: Text(l10n.bankTransferMethodLabel)),
                ],
                onChanged: (v) => setState(() => _method = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _referenceController,
                decoration: InputDecoration(labelText: l10n.quranLiveTransactionReferenceLabel),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 160,
                child: ImagePickField(label: l10n.quranLiveScreenshotLabel, file: _screenshot, alreadyUploaded: false, onTap: _pickScreenshot),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l10n.quranLiveSubmitPaymentButton),
              ),
            ],
          ),
        );
      },
    );
  }
}
