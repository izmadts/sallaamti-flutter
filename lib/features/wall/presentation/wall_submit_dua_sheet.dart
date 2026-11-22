import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/wall_repository.dart';

class WallSubmitDuaSheet extends ConsumerStatefulWidget {
  const WallSubmitDuaSheet({super.key});

  @override
  ConsumerState<WallSubmitDuaSheet> createState() => _WallSubmitDuaSheetState();
}

class _WallSubmitDuaSheetState extends ConsumerState<WallSubmitDuaSheet> {
  final _bodyController = TextEditingController();
  bool _isAnonymous = false;
  final List<File> _images = [];
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 1280, maxHeight: 1280);
    if (picked.isEmpty) return;
    setState(() {
      _images.addAll(picked.map((p) => File(p.path)));
      if (_images.length > 10) _images.removeRange(10, _images.length);
    });
  }

  void _removeImage(int index) => setState(() => _images.removeAt(index));

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      setState(() => _error = l10n.wallDuaBodyRequiredError);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(wallRepositoryProvider).submitDua(body: body, isAnonymous: _isAnonymous, images: _images);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              Text(l10n.postToTheWallTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.wallDuaReviewNoticeMessage,
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
            decoration: InputDecoration(hintText: l10n.wallDuaPromptHint),
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < _images.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_images[i], width: 72, height: 72, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => _removeImage(i),
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 13, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_images.length < 10)
                  InkWell(
                    onTap: _pickImages,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Icon(Icons.add_photo_alternate_outlined, color: Colors.grey.shade500),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            l10n.wallUpTo10PhotosMessage,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.postAnonymouslyLabel),
            value: _isAnonymous,
            onChanged: (v) => setState(() => _isAnonymous = v),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(l10n.submitButton),
          ),
        ],
      ),
    );
  }
}
