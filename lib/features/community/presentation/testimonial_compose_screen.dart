import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
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
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked != null && mounted) {
      setState(() => _photo = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final (_, message) = await ref.read(communityRepositoryProvider).saveTestimonial(
            id: widget.existing?.id,
            name: _name.text.trim(),
            location: _location.text.trim().isEmpty ? null : _location.text.trim(),
            content: _content.text.trim(),
            rating: _rating,
            photo: _photo,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      context.pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save your testimonial. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('community'),
      child: Scaffold(
        appBar: AppBar(title: Text(_isEditing ? 'Edit Testimonial' : 'Share Your Story')),
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
                            'This is live on the website. Editing it sends it back for review first.',
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
                requiredLabel('Your name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(hintText: 'How you\'d like to be credited'),
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Your name is required.' : null,
                ),
                const SizedBox(height: 8),
                Text('City / Country (optional)', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(hintText: 'e.g. Lahore, Pakistan'),
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 8),
                requiredLabel('How would you rate us?'),
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
                requiredLabel('Your story'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _content,
                  decoration: const InputDecoration(
                    hintText: 'What did Sallaamti help you with, and how did it go?',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 8,
                  minLines: 5,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Please tell us about your experience.' : null,
                ),
                const SizedBox(height: 8),
                Text('Your photo (optional)', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                ImagePickField(
                  label: 'Add a photo',
                  file: _photo,
                  alreadyUploaded: _isEditing && widget.existing!.photoUrl != null,
                  onTap: _pickPhoto,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isEditing ? 'Save Changes' : 'Submit'),
                ),
                const SizedBox(height: 10),
                Text(
                  'Testimonials appear on the website once our team has reviewed them.',
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
