import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/image_pick_field.dart';
import '../../../shared/widgets/required_label.dart';
import '../data/donation_repository.dart';
import 'donation_history_screen.dart';

String donationMethodLabel(AppLocalizations l10n, String value) => {
      'bank_transfer': l10n.donationMethodBankTransferLabel,
      'international': l10n.donationMethodInternationalLabel,
    }[value] ?? value;

String donationPurposeLabel(AppLocalizations l10n, String? value) => {
      'general': l10n.donationPurposeGeneral,
      'quran_education': l10n.donationPurposeQuranEducation,
      'orphan_support': l10n.donationPurposeOrphanSupport,
      'nikah_fund': l10n.donationPurposeNikahFund,
    }[value] ?? (value ?? '');

class DonationScreen extends ConsumerStatefulWidget {
  const DonationScreen({super.key});

  @override
  ConsumerState<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends ConsumerState<DonationScreen> {
  static const _methodKeys = ['bank_transfer', 'international'];

  DonationMeta? _meta;
  bool _loading = true;
  String? _error;

  num? _selectedTier;
  final _customAmountController = TextEditingController();
  bool _useCustomAmount = false;
  String? _purpose;
  String? _method;
  bool _isAnonymous = false;
  File? _screenshot;
  final _messageController = TextEditingController();

  bool _submitting = false;
  bool _submitted = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final meta = await ref.read(donationRepositoryProvider).meta();
      setState(() {
        _meta = meta;
        if (meta.tiers.isNotEmpty) _selectedTier = meta.tiers.first;
        if (meta.purposes.isNotEmpty) _purpose = meta.purposes.first.value;
        _method = _availableMethods(meta).isNotEmpty ? _availableMethods(meta).first : null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      // Called from initState() on first load, so the Localizations
      // InheritedWidget may not be registered yet if this throws before any
      // await yields control — looked up here (after the await above has
      // already suspended at least once) rather than hoisted to the top.
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Both methods pay into the same bank account (just labeled Pakistan vs
  // international wire) — only offer either once there's actually
  // something configured to send money to.
  List<String> _availableMethods(DonationMeta meta) => meta.paymentInstructions.hasAnyMethod ? _methodKeys : [];

  num? get _amount {
    if (_useCustomAmount) return num.tryParse(_customAmountController.text.trim());
    return _selectedTier;
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.nikahCopiedToClipboard), duration: const Duration(seconds: 2)));
    }
  }

  Widget _copyableRow(String value, {TextStyle? style}) {
    return Row(
      children: [
        Expanded(child: Text(value, style: style)),
        const SizedBox(width: 4),
        InkWell(
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
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1280, maxHeight: 1280);
    if (picked != null) setState(() => _screenshot = File(picked.path));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final amount = _amount;
    if (amount == null || amount < 100) {
      setState(() => _submitError = l10n.donationMinAmountError);
      return;
    }
    if (_method == null) {
      setState(() => _submitError = l10n.donationNoMethodConfiguredError);
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      await ref.read(donationRepositoryProvider).submit(
            amount: amount,
            paymentMethod: _method!,
            purpose: _purpose,
            message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
            isAnonymous: _isAnonymous,
            screenshot: _screenshot,
          );
      setState(() => _submitted = true);
    } on ApiException catch (e) {
      setState(() => _submitError = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _submitError = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Theme(
      data: ModuleThemes.forModule('donation'),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.donateTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: l10n.myDonationsLabel,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DonationHistoryScreen())),
            ),
          ],
        ),
        body: SafeArea(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }

    if (_submitted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🤲', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(l10n.donationThankYouTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                l10n.donationSubmittedMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => context.go('/dashboard'), child: Text(l10n.backToDashboardButton)),
            ],
          ),
        ),
      );
    }

    final meta = _meta!;
    final methods = _availableMethods(meta);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('🤲', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(l10n.supportSallaamtiTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(
            l10n.donationHadithQuote,
            style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic, fontSize: 13),
          ),
          const SizedBox(height: 20),
          if (_submitError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
              child: Text(_submitError!, style: TextStyle(color: Colors.red.shade700)),
            ),
            const SizedBox(height: 16),
          ],
          Text(l10n.chooseAnAmountLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tier in meta.tiers)
                _AmountChip(
                  label: l10n.pkrAmountChipLabel(tier.toString()),
                  selected: !_useCustomAmount && _selectedTier == tier,
                  onTap: () => setState(() {
                    _useCustomAmount = false;
                    _selectedTier = tier;
                  }),
                ),
              _AmountChip(
                label: l10n.customAmountLabel,
                selected: _useCustomAmount,
                onTap: () => setState(() => _useCustomAmount = true),
              ),
            ],
          ),
          if (_useCustomAmount) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _customAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(label: requiredLabel(l10n.amountPkrLabel)),
            ),
          ],
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _purpose,
            decoration: InputDecoration(labelText: l10n.purposeLabel),
            items: meta.purposes.map((p) => DropdownMenuItem(value: p.value, child: Text(donationPurposeLabel(l10n, p.value)))).toList(),
            onChanged: (v) => setState(() => _purpose = v),
          ),
          const SizedBox(height: 16),
          if (meta.paymentInstructions.hasAnyMethod)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.nikahSendPaymentTo, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    if ((meta.paymentInstructions.bankName ?? '').isNotEmpty)
                      Text(l10n.nikahBankLabel(meta.paymentInstructions.bankName ?? ''), style: TextStyle(color: Colors.grey.shade700)),
                    if ((meta.paymentInstructions.accountTitle ?? '').isNotEmpty)
                      Text(l10n.nikahAccountTitleLabel(meta.paymentInstructions.accountTitle ?? ''), style: TextStyle(color: Colors.grey.shade700)),
                    if ((meta.paymentInstructions.bankAccountNumber ?? '').isNotEmpty)
                      Row(
                        children: [
                          Text(l10n.nikahAccountNoLabel, style: TextStyle(color: Colors.grey.shade700)),
                          Expanded(child: _copyableRow(meta.paymentInstructions.bankAccountNumber!, style: TextStyle(color: Colors.grey.shade700))),
                        ],
                      ),
                    if ((meta.paymentInstructions.bankAccountIban ?? '').isNotEmpty)
                      Row(
                        children: [
                          Text(l10n.nikahIbanLabel, style: TextStyle(color: Colors.grey.shade700)),
                          Expanded(child: _copyableRow(meta.paymentInstructions.bankAccountIban!, style: TextStyle(color: Colors.grey.shade700))),
                        ],
                      ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
              child: Text(
                l10n.nikahPaymentNotConfiguredMessage,
                style: const TextStyle(color: Colors.deepOrange),
              ),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: InputDecoration(label: requiredLabel(l10n.paymentMethodLabel)),
            items: methods.map((m) => DropdownMenuItem(value: m, child: Text(donationMethodLabel(l10n, m)))).toList(),
            onChanged: methods.isEmpty ? null : (v) => setState(() => _method = v),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            child: ImagePickField(
              label: l10n.donationScreenshotOptionalLabel,
              file: _screenshot,
              alreadyUploaded: false,
              onTap: _pickScreenshot,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _messageController,
            decoration: InputDecoration(labelText: l10n.donationNoteOptionalLabel),
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.donateAnonymouslyLabel),
            value: _isAnonymous,
            onChanged: (v) => setState(() => _isAnonymous = v),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(l10n.submitDonationButton),
          ),
        ],
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AmountChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.white,
          border: Border.all(color: selected ? primary : Colors.grey.shade300, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
