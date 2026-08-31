import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../shared/widgets/image_pick_field.dart';
import '../../../shared/widgets/required_label.dart';
import '../data/donation_repository.dart';
import 'donation_history_screen.dart';

class DonationScreen extends ConsumerStatefulWidget {
  const DonationScreen({super.key});

  @override
  ConsumerState<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends ConsumerState<DonationScreen> {
  static const _methodLabels = {'bank_transfer': 'Bank Transfer (Pakistan)', 'international': 'International Wire'};

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
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Both methods pay into the same bank account (just labeled Pakistan vs
  // international wire) — only offer either once there's actually
  // something configured to send money to.
  List<String> _availableMethods(DonationMeta meta) => meta.paymentInstructions.hasAnyMethod ? _methodLabels.keys.toList() : [];

  num? get _amount {
    if (_useCustomAmount) return num.tryParse(_customAmountController.text.trim());
    return _selectedTier;
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
    final amount = _amount;
    if (amount == null || amount < 100) {
      setState(() => _submitError = 'Please enter an amount of at least PKR 100.');
      return;
    }
    if (_method == null) {
      setState(() => _submitError = 'No payment method is configured yet — please contact support.');
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
      if (mounted) setState(() => _submitError = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('donation'),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Donate'),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'My Donations',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DonationHistoryScreen())),
            ),
          ],
        ),
        body: SafeArea(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
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
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
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
              const Text('JazakAllah Khair!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Your donation has been submitted. Our team will verify it within 24 hours, in sha Allah.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => context.go('/dashboard'), child: const Text('Back to Dashboard')),
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
          const Text('Support Sallaamti', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(
            '"The believer\'s shade on the Day of Resurrection will be his charity." — Tirmidhi',
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
          const Text('Choose an Amount', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tier in meta.tiers)
                _AmountChip(
                  label: 'PKR ${tier.toString()}',
                  selected: !_useCustomAmount && _selectedTier == tier,
                  onTap: () => setState(() {
                    _useCustomAmount = false;
                    _selectedTier = tier;
                  }),
                ),
              _AmountChip(
                label: 'Custom',
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
              decoration: InputDecoration(label: requiredLabel('Amount (PKR)')),
            ),
          ],
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _purpose,
            decoration: const InputDecoration(labelText: 'Purpose'),
            items: meta.purposes.map((p) => DropdownMenuItem(value: p.value, child: Text(p.label))).toList(),
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
                    const Text('Send payment to', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    if ((meta.paymentInstructions.bankName ?? '').isNotEmpty)
                      Text('Bank: ${meta.paymentInstructions.bankName}', style: TextStyle(color: Colors.grey.shade700)),
                    if ((meta.paymentInstructions.accountTitle ?? '').isNotEmpty)
                      Text('Account Title: ${meta.paymentInstructions.accountTitle}', style: TextStyle(color: Colors.grey.shade700)),
                    if ((meta.paymentInstructions.bankAccountNumber ?? '').isNotEmpty)
                      Row(
                        children: [
                          Text('Account No: ', style: TextStyle(color: Colors.grey.shade700)),
                          Expanded(child: _copyableRow(meta.paymentInstructions.bankAccountNumber!, style: TextStyle(color: Colors.grey.shade700))),
                        ],
                      ),
                    if ((meta.paymentInstructions.bankAccountIban ?? '').isNotEmpty)
                      Row(
                        children: [
                          Text('IBAN: ', style: TextStyle(color: Colors.grey.shade700)),
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
              child: const Text(
                'Payment details have not been configured yet. Please contact support before sending any payment.',
                style: TextStyle(color: Colors.deepOrange),
              ),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: InputDecoration(label: requiredLabel('Payment Method')),
            items: methods.map((m) => DropdownMenuItem(value: m, child: Text(_methodLabels[m]!))).toList(),
            onChanged: methods.isEmpty ? null : (v) => setState(() => _method = v),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            child: ImagePickField(
              label: 'Payment Screenshot (Optional)',
              file: _screenshot,
              alreadyUploaded: false,
              onTap: _pickScreenshot,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _messageController,
            decoration: const InputDecoration(labelText: 'A note to go with your donation (optional)'),
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Donate anonymously'),
            value: _isAnonymous,
            onChanged: (v) => setState(() => _isAnonymous = v),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit Donation'),
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
