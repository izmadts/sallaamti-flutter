import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/state/locale_controller.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/html_text.dart';
import '../../../shared/widgets/image_pick_field.dart';
import '../../../shared/widgets/required_label.dart';
import '../data/community_repository.dart';

// Create or edit — the same form either way, since the API takes the same
// fields for both and only the endpoint differs.
//
// Plain multiline text rather than a rich editor: the backend
// (HtmlSanitizer::cleanAuthoredText) turns it into the same safe HTML the
// web's Trix editor produces, so a post written here reads correctly on the
// website too.
class PostComposeScreen extends ConsumerStatefulWidget {
  final MemberPost? existing;
  const PostComposeScreen({super.key, this.existing});

  @override
  ConsumerState<PostComposeScreen> createState() => _PostComposeScreenState();
}

class _PostComposeScreenState extends ConsumerState<PostComposeScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _excerpt;
  late final TextEditingController _body;

  File? _coverImage;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _excerpt = TextEditingController(text: widget.existing?.excerpt ?? '');
    // body arrives as HTML from the API; strip it back to something editable
    // rather than showing the author their own text wrapped in tags.
    _body = TextEditingController(text: stripHtmlToText(widget.existing?.body));
  }

  @override
  void dispose() {
    _title.dispose();
    _excerpt.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 1280, maxHeight: 1280);
    if (picked != null && mounted) {
      setState(() => _coverImage = File(picked.path));
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
      // Written in whatever language the member is currently using the app
      // in — no separate picker, so there's nothing for them to get wrong.
      final language = ref.read(localeControllerProvider)?.languageCode ?? 'en';

      final (post, _) = await ref.read(communityRepositoryProvider).savePost(
            id: widget.existing?.id,
            title: _title.text.trim(),
            body: _body.text.trim(),
            language: language,
            excerpt: _excerpt.text.trim().isEmpty ? null : _excerpt.text.trim(),
            coverImage: _coverImage,
          );

      if (!mounted) return;
      final message = _isEditing
          ? l10n.communityPostUpdatedMessage
          : (post.isPublished ? l10n.communityPostLiveMessage : l10n.communityPostSubmittedMessage);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      context.pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.communitySavePostError);
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
        appBar: AppBar(title: Text(_isEditing ? l10n.editPostTitle : l10n.writeAPostButton)),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                if (_isEditing && widget.existing!.isPublished)
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
                            l10n.postLiveEditNoticeMessage,
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
                requiredLabel(l10n.titleLabel),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _title,
                  decoration: InputDecoration(hintText: l10n.postAboutHint),
                  maxLength: 150,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => (v ?? '').trim().isEmpty ? l10n.giveYourPostATitleError : null,
                ),
                const SizedBox(height: 8),
                requiredLabel(l10n.yourPostLabel),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _body,
                  decoration: InputDecoration(
                    hintText: l10n.writeFreelyHint,
                    alignLabelWithHint: true,
                  ),
                  maxLines: 12,
                  minLines: 8,
                  maxLength: 20000,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => (v ?? '').trim().isEmpty ? l10n.writeSomethingError : null,
                ),
                const SizedBox(height: 8),
                Text(l10n.shortSummaryOptionalLabel, style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _excerpt,
                  decoration: InputDecoration(
                    hintText: l10n.shortSummaryHint,
                  ),
                  maxLength: 300,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 8),
                Text(l10n.coverImageOptionalLabel, style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                ImagePickField(
                  label: l10n.addACoverImageLabel,
                  file: _coverImage,
                  alreadyUploaded: _isEditing && widget.existing!.coverImageUrl != null,
                  onTap: _pickCover,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isEditing ? l10n.saveChangesButton : l10n.submitForReviewButton),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.postsReviewNoticeMessage,
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
