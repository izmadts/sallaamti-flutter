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
import '../data/nikah_hire_repository.dart';
import '../domain/nikah_profile.dart';

// Shown right after hiring a counselor (nikah_counselor_picker_screen.dart)
// — same payment-proof pattern as nikah_payment_screen.dart's one-time fee,
// just against the counseling package catalog instead. Admin still
// confirms the payment before the package actually activates.
class NikahHirePackageScreen extends ConsumerStatefulWidget {
  const NikahHirePackageScreen({super.key});

  @override
  ConsumerState<NikahHirePackageScreen> createState() => _NikahHirePackageScreenState();
}

class _NikahHirePackageScreenState extends ConsumerState<NikahHirePackageScreen> {
  List<CounselorPackage> _packages = [];
  CounselorPackage? _selected;
  NikahPaymentInstructions _paymentInstructions = const NikahPaymentInstructions();
  String _method = 'jazzcash';
  File? _screenshot;
  bool _loading = true;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(nikahHireRepositoryProvider);
      final result = await repo.packages();
      setState(() {
        _packages = result.packages;
        _paymentInstructions = result.paymentInstructions;
        if (result.packages.isNotEmpty) _selected = result.packages.first;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickScreenshot() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _screenshot = File(picked.path));
  }

  Future<void> _submit() async {
    if (_selected == null) return;
    if (_screenshot == null) {
      setState(() => _error = 'Please upload a payment screenshot.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final repo = ref.read(nikahHireRepositoryProvider);
      await repo.submitPackage(
        packageId: _selected!.id,
        paymentMethod: _method,
        screenshot: _screenshot!,
      );
      setState(() => _submitted = true);
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Theme(
        data: ModuleThemes.forModule('nikah'),
        child: Scaffold(
          appBar: AppBar(title: const Text('Payment Submitted')),
          body: Center(
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
                    'Your counselor and our team will confirm it shortly. You can message your counselor anytime in the meantime.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(onPressed: () => context.go('/nikah'), child: const Text('Back to Nikah')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Theme(
      data: ModuleThemes.forModule('nikah'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Choose a Package')),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
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
                      for (final package in _packages) _PackageOption(
                        package: package,
                        selected: _selected?.id == package.id,
                        onTap: () => setState(() => _selected = package),
                      ),
                      const SizedBox(height: 12),
                      if (_paymentInstructions.hasAnyMethod)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Send payment to', style: TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 12),
                                if (_paymentInstructions.hasJazzcash) ...[
                                  const Text('📱 JazzCash', style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  _copyableRow(_paymentInstructions.jazzcashNumber!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                  if ((_paymentInstructions.jazzcashAccountTitle ?? '').isNotEmpty)
                                    Text(_paymentInstructions.jazzcashAccountTitle!, style: TextStyle(color: Colors.grey.shade600)),
                                  const SizedBox(height: 12),
                                ],
                                if (_paymentInstructions.hasEasypaisa) ...[
                                  const Text('📱 EasyPaisa', style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  _copyableRow(_paymentInstructions.easypaisaNumber!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 12),
                                ],
                                if (_paymentInstructions.hasBankTransfer) ...[
                                  const Text('🏦 Bank Transfer', style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text('Bank: ${_paymentInstructions.bankName}', style: TextStyle(color: Colors.grey.shade700)),
                                  if ((_paymentInstructions.bankAccountTitle ?? '').isNotEmpty)
                                    Text('Account Title: ${_paymentInstructions.bankAccountTitle}', style: TextStyle(color: Colors.grey.shade700)),
                                  if ((_paymentInstructions.bankAccountNumber ?? '').isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Account No: ', style: TextStyle(color: Colors.grey.shade700)),
                                        _copyableRow(_paymentInstructions.bankAccountNumber!, style: TextStyle(color: Colors.grey.shade700)),
                                      ],
                                    ),
                                  if ((_paymentInstructions.bankAccountIban ?? '').isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('IBAN: ', style: TextStyle(color: Colors.grey.shade700)),
                                        _copyableRow(_paymentInstructions.bankAccountIban!, style: TextStyle(color: Colors.grey.shade700)),
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
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _method,
                        decoration: InputDecoration(label: requiredLabel('Payment Method')),
                        items: const [
                          DropdownMenuItem(value: 'jazzcash', child: Text('JazzCash')),
                          DropdownMenuItem(value: 'easypaisa', child: Text('EasyPaisa')),
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
                        onPressed: (_submitting || _selected == null) ? null : _submit,
                        child: _submitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit Payment'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _PackageOption extends StatelessWidget {
  final CounselorPackage package;
  final bool selected;
  final VoidCallback onTap;
  const _PackageOption({required this.package, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.06) : Colors.white,
          border: Border.all(color: selected ? primary : Colors.grey.shade300, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? primary : Colors.grey.shade400),
                const SizedBox(width: 8),
                Expanded(child: Text(package.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                Text('${package.currency ?? 'Rs.'} ${package.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            if ((package.tagline ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(package.tagline!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
            if (package.proposalLimit != null) ...[
              const SizedBox(height: 6),
              Text('Up to ${package.proposalLimit} proposals', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}
