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
  Map<String, String> _methodLabels(AppLocalizations l10n) => {
        'jazzcash': l10n.jazzcashMethodLabel,
        'easypaisa': l10n.easypaisaMethodLabel,
        'bank_transfer': l10n.bankTransferMethodLabel,
      };

  List<CounselorPackage> _packages = [];
  CounselorPackage? _selected;
  NikahPaymentInstructions _paymentInstructions = const NikahPaymentInstructions();
  String? _method;
  File? _screenshot;
  bool _loading = true;
  bool _submitting = false;
  bool _submitted = false;
  bool _releasing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _copy(String value) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.nikahCopiedToClipboard), duration: const Duration(seconds: 2)));
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

  // Only offer a method the member can actually pay into — a method
  // showing up as selectable with no account behind it just strands them
  // at the submit step with nowhere to send the money.
  List<String> get _availableMethods => [
        if (_paymentInstructions.hasJazzcash) 'jazzcash',
        if (_paymentInstructions.hasEasypaisa) 'easypaisa',
        if (_paymentInstructions.hasBankTransfer) 'bank_transfer',
      ];

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
        _method = _availableMethods.isNotEmpty ? _availableMethods.first : null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      setState(() => _error = AppLocalizations.of(context)!.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Owner (21 Nov 2026): a member who hits "Choose [counselor]" by mistake
  // landed here (pushReplacement from the picker, so there's no back-stack
  // to the picker either) with no way to undo it — release() already
  // existed and worked fine on nikah_payment_screen.dart's "Go Back", but
  // this screen (the one a mistaken hire actually lands on) never exposed
  // it. No payment-status check needed here, unlike that screen's
  // canRelease — reaching this screen at all means nothing's been
  // submitted yet for this lead.
  Future<void> _release() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.nikahChooseDifferentCounselorTitle),
        content: Text(l10n.nikahChooseDifferentCounselorMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.nikahGoBack)),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _releasing = true);
    try {
      await ref.read(nikahHireRepositoryProvider).release();
      if (mounted) context.go('/nikah');
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    } finally {
      if (mounted) setState(() => _releasing = false);
    }
  }

  Future<void> _pickScreenshot() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1280, maxHeight: 1280);
    if (picked != null) setState(() => _screenshot = File(picked.path));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selected == null || _method == null) return;
    if (_screenshot == null) {
      setState(() => _error = l10n.nikahUploadScreenshotRequired);
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
        paymentMethod: _method!,
        screenshot: _screenshot!,
      );
      setState(() => _submitted = true);
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_submitted) {
      return Theme(
        data: ModuleThemes.forModule('nikah'),
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.nikahPackagePaymentSubmittedTitle)),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('✅', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  Text(l10n.nikahPackagePaymentSubmittedTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    l10n.nikahPackageSubmittedFollowUpMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(onPressed: () => context.go('/nikah'), child: Text(l10n.nikahBackToNikah)),
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
        appBar: AppBar(
          title: Text(l10n.nikahChoosePackageButton),
          actions: [
            TextButton(
              // Same AppBarTheme.foregroundColor fix as nikah_payment_screen.dart's
              // own "Go Back" — without it this resolves to ColorScheme.primary,
              // same rose as the bar background, making the button invisible.
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _releasing ? null : _release,
              child: _releasing
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l10n.nikahGoBack),
            ),
          ],
        ),
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
                                Text(l10n.nikahSendPaymentTo, style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 12),
                                if (_paymentInstructions.hasJazzcash) ...[
                                  Text(l10n.nikahJazzcashLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  _copyableRow(_paymentInstructions.jazzcashNumber!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                  if ((_paymentInstructions.jazzcashAccountTitle ?? '').isNotEmpty)
                                    Text(_paymentInstructions.jazzcashAccountTitle!, style: TextStyle(color: Colors.grey.shade600)),
                                  const SizedBox(height: 12),
                                ],
                                if (_paymentInstructions.hasEasypaisa) ...[
                                  Text(l10n.nikahEasypaisaLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  _copyableRow(_paymentInstructions.easypaisaNumber!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 12),
                                ],
                                if (_paymentInstructions.hasBankTransfer) ...[
                                  Text(l10n.nikahBankTransferLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(l10n.nikahBankLabel(_paymentInstructions.bankName ?? ''), style: TextStyle(color: Colors.grey.shade700)),
                                  if ((_paymentInstructions.bankAccountTitle ?? '').isNotEmpty)
                                    Text(l10n.nikahAccountTitleLabel(_paymentInstructions.bankAccountTitle!), style: TextStyle(color: Colors.grey.shade700)),
                                  if ((_paymentInstructions.bankAccountNumber ?? '').isNotEmpty)
                                    Row(
                                      children: [
                                        Text(l10n.nikahAccountNoLabel, style: TextStyle(color: Colors.grey.shade700)),
                                        Expanded(child: _copyableRow(_paymentInstructions.bankAccountNumber!, style: TextStyle(color: Colors.grey.shade700))),
                                      ],
                                    ),
                                  if ((_paymentInstructions.bankAccountIban ?? '').isNotEmpty)
                                    Row(
                                      children: [
                                        Text(l10n.nikahIbanLabel, style: TextStyle(color: Colors.grey.shade700)),
                                        Expanded(child: _copyableRow(_paymentInstructions.bankAccountIban!, style: TextStyle(color: Colors.grey.shade700))),
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
                          child: Text(
                            l10n.nikahPaymentNotConfiguredMessage,
                            style: const TextStyle(color: Colors.deepOrange),
                          ),
                        ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _method,
                        decoration: InputDecoration(label: requiredLabel('Payment Method')),
                        items: _availableMethods
                            .map((m) => DropdownMenuItem(value: m, child: Text(_methodLabels(l10n)[m]!)))
                            .toList(),
                        onChanged: _availableMethods.isEmpty ? null : (v) => setState(() => _method = v),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 160,
                        child: ImagePickField(
                          label: l10n.nikahPaymentScreenshotLabel,
                          file: _screenshot,
                          alreadyUploaded: false,
                          onTap: _pickScreenshot,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: (_submitting || _selected == null || _method == null) ? null : _submit,
                        child: _submitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(l10n.nikahSubmitPaymentButton),
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
    final l10n = AppLocalizations.of(context)!;
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
              Text(l10n.nikahProposalLimitLabel(package.proposalLimit!), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}
