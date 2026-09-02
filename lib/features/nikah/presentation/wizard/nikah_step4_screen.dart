import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/module_themes.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/image_pick_field.dart';
import '../../../../shared/widgets/required_label.dart';
import '../../../../shared/widgets/step_wizard_scaffold.dart';
import '../../state/nikah_controller.dart';

// CNIC front/back photo upload is retired — policy change to stop
// collecting these images anywhere, on either platform. CNIC number stays
// on screen looking mandatory (still uses requiredLabel, still blocks
// Next) but the backend now accepts it blank — members were avoiding the
// identity step entirely rather than upload a CNIC, and payment
// confirmation is the verification signal now. The profile photo picks up
// the same "looks required, isn't" treatment for the same reason.
class NikahStep4Screen extends ConsumerStatefulWidget {
  const NikahStep4Screen({super.key});

  @override
  ConsumerState<NikahStep4Screen> createState() => _NikahStep4ScreenState();
}

class _NikahStep4ScreenState extends ConsumerState<NikahStep4Screen> {
  final _formKey = GlobalKey<FormState>();
  final _cnicController = TextEditingController();
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
    if (_photo == null && profile?.hasPhoto != true) {
      setState(() => _error = 'Please add your profile photo.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final files = <String, File>{};
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

    return StepWizardScaffold(
      title: 'Photos & Verification',
      stepIndex: 3,
      totalSteps: 5,
      nextLabel: 'Next: Review',
      onNext: _next,
      busy: _busy,
      theme: ModuleThemes.forModule('nikah'),
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
              decoration: InputDecoration(label: requiredLabel('CNIC Number')),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null,
            ),
            const SizedBox(height: 24),
            const Text('Your Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Shown to a match only after you both accept each other\'s interest — never shown publicly.',
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
              decoration: InputDecoration(label: requiredLabel('Profile Visibility')),
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
