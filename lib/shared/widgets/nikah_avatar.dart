import 'package:flutter/material.dart';

import '../../core/storage/secure_store.dart';

// Nikah photo/CNIC URLs are served by an authenticated API endpoint, not a
// public CDN — plain NetworkImage sends no Authorization header, so the
// request 401s. This attaches the stored bearer token before rendering.
class NikahAvatar extends StatelessWidget {
  final String? photoUrl;
  final double radius;

  const NikahAvatar({super.key, required this.photoUrl, this.radius = 32});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final placeholder = CircleAvatar(
      radius: radius,
      backgroundColor: primary.withValues(alpha: 0.1),
      child: Icon(Icons.person, color: primary, size: radius),
    );

    if (photoUrl == null) return placeholder;

    return FutureBuilder<String?>(
      future: SecureStore.readToken(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return placeholder;

        return CircleAvatar(
          radius: radius,
          backgroundColor: primary.withValues(alpha: 0.1),
          backgroundImage: NetworkImage(
            photoUrl!,
            headers: {'Authorization': 'Bearer ${snapshot.data}'},
          ),
        );
      },
    );
  }
}
