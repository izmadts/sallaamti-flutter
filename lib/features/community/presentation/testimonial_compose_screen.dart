import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/html_text.dart';
import '../../../shared/widgets/image_pick_field.dart';
import '../../../shared/widgets/required_label.dart';
import '../../auth/state/auth_controller.dart';
import '../data/community_repository.dart';

class TestimonialComposeScreen extends ConsumerStatefulWidget {
  final MemberTestimonial? existing;
  const TestimonialComposeScreen({super.key, this.existing});

  @override
  ConsumerState<TestimonialComposeScreen> createState() => _TestimonialComposeScreenState();
}

class _TestimonialComposeScreenState extends ConsumerState<TestimonialComposeScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _content;

  late int _rating;
  File? _photo;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    // Prefill the name from the account rather than making someone retype
    // what we already know — they can still change it.
    final accountName = ref.read(authControllerProvider).user?.name ?? '';
    final accountCity = ref.read(authControllerProvider).user?.city ?? '';

    _name = TextEditingController(text: widget.existing?.name ?? accountName);
    _location = TextEditingController(text: widget.existing?.location ?? accountCity);
    _content = TextEditingController(text: stripHtmlToText(widget.existing?.content));
    _rating = widget.existing?.rating ?? 5;
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 1280, maxHeight: 1280);
    if (picked != null && mounted) {
      setState(() => _photo = File(picked.path));
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(communityRepositoryProvider).saveTestimonial(
            id: widget.existing?.id,
            name: _name.text.trim(),
            location: _location.text.trim().isEmpty ? null : _location.text.trim(),
            content: _content.text.trim(),
            rating: _rating,
            photo: _photo,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? l10n.communityTestimonialUpdatedMessage : l10n.communityTestimonialSubmittedMessage)),
      );
      context.pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.communitySaveTestimonialError);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Theme(
      data: ModuleThemes.forModule('community'),
      child: Scaffold(
        appBar: AppBar(title: Text(_isEditing ? l10n.editSuccessStoryTitle : l10n.shareYourStoryTitle)),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                if (_isEditing && widget.existing!.isApproved)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.amber.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.testimonialLiveEditNoticeMessage,
                            style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_error != null) ...[
                  ErrorBanner(message: _error!),
                  const SizedBox(height: 16),
                ],
                requiredLabel(l10n.yourNameLabel),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(hintText: l10n.howCreditedHint),
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v ?? '').trim().isEmpty ? l10n.yourNameRequiredError : null,
                ),
                const SizedBox(height: 8),
                Text(l10n.cityCountryOptionalLabel, style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _location,
                  decoration: InputDecoration(hintText: l10n.cityCountryHint),
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 8),
                requiredLabel(l10n.howWouldYouRateUsLabel),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(
                    5,
                    (i) => IconButton(
                      onPressed: () => setState(() => _rating = i + 1),
                      icon: Icon(
                        i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 34,
                        color: const Color(0xFFB8962E),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                requiredLabel(l10n.yourStoryLabel),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _content,
                  decoration: InputDecoration(
                    hintText: l10n.yourStoryHint,
                    alignLabelWithHint: true,
                  ),
                  maxLines: 8,
                  minLines: 5,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => (v ?? '').trim().isEmpty ? l10n.tellUsAboutExperienceError : null,
                ),
                const SizedBox(height: 8),
                Text(l10n.yourPhotoOptionalLabel, style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                ImagePickField(
                  label: l10n.addAPhotoLabel,
                  file: _photo,
                  alreadyUploaded: _isEditing && widget.existing!.photoUrl != null,
                  onTap: _pickPhoto,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isEditing ? l10n.saveChangesButton : l10n.submitButton),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.successStoriesReviewNoticeMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
