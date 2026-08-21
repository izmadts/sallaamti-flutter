import 'dart:io';

import 'package:flutter/material.dart';

// A tappable card for picking a single image — shows a thumbnail once
// picked locally, or a checkmark if the server already has one on file
// from a previous save (so re-opening a wizard step doesn't look like the
// upload was lost). Used for CNIC front/back, profile photo, and the
// donation-style payment screenshot.
class ImagePickField extends StatelessWidget {
  final String label;
  final File? file;
  final bool alreadyUploaded;
  final VoidCallback onTap;

  const ImagePickField({
    super.key,
    required this.label,
    required this.file,
    required this.alreadyUploaded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = file != null || alreadyUploaded;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasImage ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
            width: hasImage ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: file != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(file!, fit: BoxFit.cover),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.edit, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      alreadyUploaded ? Icons.check_circle : Icons.add_a_photo_outlined,
                      color: alreadyUploaded ? Colors.green : Colors.grey.shade500,
                      size: 28,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alreadyUploaded ? '$label ✓' : label,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
