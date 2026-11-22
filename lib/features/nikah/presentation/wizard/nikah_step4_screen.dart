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
import '../../domain/nikah_profile.dart';
import '../../state/nikah_controller.dart';

// CNIC front/back photo upload is retired — policy change to stop
// collecting these images anywhere, on either platform. CNIC number is now
// genuinely optional on screen too (no validator, label says so) — the
// backend already accepted it blank; payment confirmation is the
// verification signal, not CNIC. The profile photo still looks required
// and still blocks Next (out of scope for this change).
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
  bool _prefilled = false;

  @override
  void dispose() {
    _cnicController.dispose();
    super.dispose();
  }

  // Found live (16 Nov 2026) — these two never actually read the member's
  // real saved values; every edit pass through this step quietly reset
  // Visibility back to "Public" and photo-sharing back to "on" unless
  // someone happened to notice and re-pick their real settings before
  // tapping Next. CNIC itself stays genuinely blank by design — the API
  // only ever returns hasCnicNumber (a bool), never the real number back
  // to the client.
  void _prefillFrom(NikahProfile profile) {
    _prefilled = true;
    _allowPhotoSharing = profile.allowPhotoSharing;
    _visibility = profile.visibility;
  }

  Future<void> _pick(void Function(File) onPicked) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1280, maxHeight: 1280);
    if (picked != null) {
      setState(() => onPicked(File(picked.path)));
    }
  }

  Future<void> _next() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    final profile = ref.read(nikahControllerProvider).profile;
    if (_photo == null && profile?.hasPhoto != true) {
      setState(() => _error = l10n.nikahAddPhotoRequired);
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
    final l10n = AppLocalizations.of(context)!;
    final profile = ref.watch(nikahControllerProvider).profile;
    if (!_prefilled && profile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _prefillFrom(profile));
      });
    }

    return StepWizardScaffold(
      title: l10n.nikahPhotosVerificationTitle,
      stepIndex: 3,
      totalSteps: 5,
      nextLabel: l10n.nikahNextReview,
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
            Text(l10n.nikahIdentityVerificationTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              l10n.nikahCnicPrivacyMessage,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cnicController,
              decoration: InputDecoration(labelText: l10n.nikahCnicOptionalLabel),
            ),
            const SizedBox(height: 24),
            Text(l10n.nikahYourPhotoTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              l10n.nikahPhotoPrivacyMessage,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 140,
              child: ImagePickField(
                label: l10n.nikahAddPhotoLabel,
                file: _photo,
                alreadyUploaded: profile?.hasPhoto ?? false,
                onTap: () => _pick((f) => _photo = f),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.nikahAllowPhotoSharingLabel),
              value: _allowPhotoSharing,
              onChanged: (v) => setState(() => _allowPhotoSharing = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              decoration: InputDecoration(label: requiredLabel(l10n.nikahProfileVisibilityLabel)),
              isExpanded: true,
              items: [
                DropdownMenuItem(value: 'public', child: Text(l10n.nikahVisibilityPublic)),
                DropdownMenuItem(value: 'members_only', child: Text(l10n.nikahVisibilityMembersOnly)),
                DropdownMenuItem(value: 'matchmaker_assisted', child: Text(l10n.nikahVisibilityMatchmakerAssisted)),
                DropdownMenuItem(value: 'confidential', child: Text(l10n.nikahVisibilityConfidential)),
              ],
              onChanged: (v) => setState(() => _visibility = v!),
            ),
          ],
        ),
      ),
    );
  }
}
