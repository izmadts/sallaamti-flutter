import 'package:flutter/material.dart';

import '../../features/auth/presentation/email_verification_dialog.dart';
import '../router/app_router.dart';

// Called from ApiClient's single response-handling choke point the moment
// any request 403s with code 'email_not_verified' — pops the verification
// dialog from wherever the blocked action happened, no per-screen wiring
// needed. Uses rootNavigatorKey rather than a BuildContext/ref, same
// reason as push_notification_service.dart's _navigateFromPushData(): this
// runs from ApiClient, a plain Dart class with no widget context of its
// own.
bool _showing = false;

void maybeShowEmailVerificationGate(String? code) {
  if (code != 'email_not_verified' || _showing) return;

  final context = rootNavigatorKey.currentContext;
  if (context == null) return;

  _showing = true;
  showDialog<void>(
    context: context,
    builder: (_) => const EmailVerificationDialog(),
  ).whenComplete(() => _showing = false);
}
