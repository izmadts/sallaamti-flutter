import 'package:flutter/material.dart';

import '../../core/storage/secure_store.dart';

// A NetworkImage-backed CircleAvatar, but for URLs served by our own API
// (e.g. /api/v1/avatar/{user}) that require the app's bearer token — a
// plain NetworkImage() never attaches it, so those URLs 401 silently and
// render a blank circle. ui-avatars.com fallback URLs (no avatar set)
// are public and skip the token fetch entirely.
class AuthedAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  final Widget? fallback;
  final Color? backgroundColor;

  const AuthedAvatar({super.key, this.url, this.radius = 20, this.fallback, this.backgroundColor});

  bool get _needsAuth => (url ?? '').contains('/api/v1/avatar/');

  @override
  Widget build(BuildContext context) {
    if ((url ?? '').isEmpty) {
      return CircleAvatar(radius: radius, backgroundColor: backgroundColor, child: fallback);
    }

    if (!_needsAuth) {
      return CircleAvatar(radius: radius, backgroundColor: backgroundColor, backgroundImage: NetworkImage(url!));
    }

    return FutureBuilder<String?>(
      future: SecureStore.readToken(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircleAvatar(radius: radius, backgroundColor: backgroundColor, child: fallback);
        }
        return CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor,
          backgroundImage: NetworkImage(url!, headers: {'Authorization': 'Bearer ${snapshot.data}'}),
        );
      },
    );
  }
}
