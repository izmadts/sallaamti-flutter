import 'package:flutter/material.dart';

import '../../core/storage/secure_store.dart';

// Nikah photo/CNIC URLs are served by an authenticated API endpoint, not a
// public CDN — plain NetworkImage sends no Authorization header, so the
// request 401s. This attaches the stored bearer token before rendering.
class NikahAvatar extends StatefulWidget {
  final String? photoUrl;
  final double radius;

  const NikahAvatar({super.key, required this.photoUrl, this.radius = 32});

  @override
  State<NikahAvatar> createState() => _NikahAvatarState();
}

class _NikahAvatarState extends State<NikahAvatar> {
  bool _failed = false;

  @override
  void didUpdateWidget(NikahAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) _failed = false;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final placeholder = CircleAvatar(
      radius: widget.radius,
      backgroundColor: primary.withValues(alpha: 0.1),
      child: Icon(Icons.person, color: primary, size: widget.radius),
    );

    if (widget.photoUrl == null || _failed) return placeholder;

    return FutureBuilder<String?>(
      future: SecureStore.readToken(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return placeholder;

        return CircleAvatar(
          radius: widget.radius,
          backgroundColor: primary.withValues(alpha: 0.1),
          // Without onBackgroundImageError, a failed load (expired token,
          // moved file, transient network error) leaves a blank colored
          // circle with no icon — falling back to the placeholder here
          // instead is what actually makes a missing photo visible as
          // "no photo" rather than invisible.
          onBackgroundImageError: (exception, stackTrace) {
            if (mounted) setState(() => _failed = true);
          },
          backgroundImage: NetworkImage(
            widget.photoUrl!,
            headers: {'Authorization': 'Bearer ${snapshot.data}'},
          ),
        );
      },
    );
  }
}
