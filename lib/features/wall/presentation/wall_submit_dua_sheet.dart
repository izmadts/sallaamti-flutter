import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/image_pick_field.dart';
import '../data/wall_repository.dart';

class WallSubmitDuaSheet extends ConsumerStatefulWidget {
  const WallSubmitDuaSheet({super.key});

  @override
  ConsumerState<WallSubmitDuaSheet> createState() => _WallSubmitDuaSheetState();
}

class _WallSubmitDuaSheetState extends ConsumerState<WallSubmitDuaSheet> {
  final _bodyController = TextEditingController();
  bool _isAnonymous = false;
  File? _image;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _submit() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      setState(() => _error = 'Please write your dua request.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(wallRepositoryProvider).submitDua(body: body, isAnonymous: _isAnonymous, image: _image);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('📣', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 8),
              const Text('Post to the Wall', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Right now you can share a dua request — our team reviews it before it appears on the Wall.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _bodyController,
            decoration: const InputDecoration(hintText: 'What would you like the community to pray for?'),
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 140,
              child: ImagePickField(
                label: 'Add a Photo (Optional)',
                file: _image,
                alreadyUploaded: false,
                onTap: _pickImage,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Post anonymously'),
            value: _isAnonymous,
            onChanged: (v) => setState(() => _isAnonymous = v),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
