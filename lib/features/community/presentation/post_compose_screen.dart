import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../shared/widgets/error_banner.dart';
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
    _body = TextEditingController(text: _htmlToPlainText(widget.existing?.body));
  }

  @override
  void dispose() {
    _title.dispose();
    _excerpt.dispose();
    _body.dispose();
    super.dispose();
  }

  static String _htmlToPlainText(String? html) {
    if (html == null || html.isEmpty) return '';

    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|h[1-6]|li)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked != null && mounted) {
      setState(() => _coverImage = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final (_, message) = await ref.read(communityRepositoryProvider).savePost(
            id: widget.existing?.id,
            title: _title.text.trim(),
            body: _body.text.trim(),
            excerpt: _excerpt.text.trim().isEmpty ? null : _excerpt.text.trim(),
            coverImage: _coverImage,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      context.pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save your post. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('community'),
      child: Scaffold(
        appBar: AppBar(title: Text(_isEditing ? 'Edit Post' : 'Write a Post')),
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
                            'This post is live. Editing it sends it back for review before it\'s public again.',
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
                requiredLabel('Title'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(hintText: 'What\'s your post about?'),
                  maxLength: 150,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Give your post a title.' : null,
                ),
                const SizedBox(height: 8),
                requiredLabel('Your post'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _body,
                  decoration: const InputDecoration(
                    hintText: 'Write freely — line breaks are kept as you type them.',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 12,
                  minLines: 8,
                  maxLength: 20000,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Write something before submitting.' : null,
                ),
                const SizedBox(height: 8),
                Text('Short summary (optional)', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _excerpt,
                  decoration: const InputDecoration(
                    hintText: 'Shown in the list. Left blank, we\'ll use your opening lines.',
                  ),
                  maxLength: 300,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 8),
                Text('Cover image (optional)', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                ImagePickField(
                  label: 'Add a cover image',
                  file: _coverImage,
                  alreadyUploaded: _isEditing && widget.existing!.coverImageUrl != null,
                  onTap: _pickCover,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isEditing ? 'Save Changes' : 'Submit for Review'),
                ),
                const SizedBox(height: 10),
                Text(
                  'Posts appear publicly once our team has reviewed them.',
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
