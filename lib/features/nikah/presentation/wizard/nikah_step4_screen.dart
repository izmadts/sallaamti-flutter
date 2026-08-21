import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/image_pick_field.dart';
import '../../../../shared/widgets/step_wizard_scaffold.dart';
import '../../state/nikah_controller.dart';

class NikahStep4Screen extends ConsumerStatefulWidget {
  const NikahStep4Screen({super.key});

  @override
  ConsumerState<NikahStep4Screen> createState() => _NikahStep4ScreenState();
}

class _NikahStep4ScreenState extends ConsumerState<NikahStep4Screen> {
  final _formKey = GlobalKey<FormState>();
  final _cnicController = TextEditingController();
  File? _cnicFront;
  File? _cnicBack;
  File? _photo;
  bool _allowPhotoSharing = true;
  String _visibility = 'public';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _cnicController.dispose();
    super.dispose();
  }

  Future<void> _pick(void Function(File) onPicked) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => onPicked(File(picked.path)));
    }
  }

  Future<void> _next() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    final profile = ref.read(nikahControllerProvider).profile;
    if (_cnicFront == null && profile?.hasCnicFrontImage != true) {
      setState(() => _error = l10n.nikahCnicFrontRequired);
      return;
    }
    if (_cnicBack == null && profile?.hasCnicBackImage != true) {
      setState(() => _error = l10n.nikahCnicBackRequired);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final files = <String, File>{};
      if (_cnicFront != null) files['cnic_front_image'] = _cnicFront!;
      if (_cnicBack != null) files['cnic_back_image'] = _cnicBack!;
      if (_photo != null) files['photo'] = _photo!;

      await ref.read(nikahControllerProvider.notifier).save({
        'cnic_number': _cnicController.text.trim(),
        'allow_photo_sharing': _allowPhotoSharing,
        'visibility': _visibility,
      }, files: files);

      if (mounted) context.push('/nikah/wizard/review');
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

    return StepWizardScaffold(
      title: 'Photos & Verification',
      stepIndex: 3,
      totalSteps: 5,
      nextLabel: 'Next: Review',
      onNext: _next,
      busy: _busy,
      errorText: _error,
      onBack: () => context.pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Identity Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Your CNIC is used only to verify you\'re a real person — it\'s never shown publicly, only our team can see it.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cnicController,
              decoration: const InputDecoration(labelText: 'CNIC Number'),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ImagePickField(
                    label: 'CNIC Front',
                    file: _cnicFront,
                    alreadyUploaded: profile?.hasCnicFrontImage ?? false,
                    onTap: () => _pick((f) => _cnicFront = f),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ImagePickField(
                    label: 'CNIC Back',
                    file: _cnicBack,
                    alreadyUploaded: profile?.hasCnicBackImage ?? false,
                    onTap: () => _pick((f) => _cnicBack = f),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Your Photo (optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Only shown to a match after you both accept each other\'s interest.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 140,
              child: ImagePickField(
                label: 'Add Photo',
                file: _photo,
                alreadyUploaded: profile?.hasPhoto ?? false,
                onTap: () => _pick((f) => _photo = f),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow my photo to be shared with matches'),
              value: _allowPhotoSharing,
              onChanged: (v) => setState(() => _allowPhotoSharing = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              decoration: const InputDecoration(labelText: 'Profile Visibility'),
              items: const [
                DropdownMenuItem(value: 'public', child: Text('Public — visible in Browse')),
                DropdownMenuItem(value: 'private', child: Text('Private — hidden from Browse')),
              ],
              onChanged: (v) => setState(() => _visibility = v!),
            ),
          ],
        ),
      ),
    );
  }
}
