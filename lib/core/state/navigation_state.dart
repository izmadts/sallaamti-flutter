import 'package:flutter_riverpod/flutter_riverpod.dart';

// Updated as a side effect of GoRouter's redirect callback (see
// app_router.dart) on every navigation — gives the bottom nav bar cheap,
// always-current answers to "what route are we on" (for tab highlighting)
// and "which module did the member most recently open" (for the 3rd tab's
// dynamic icon/label), without either needing GoRouterState plumbed into a
// widget that lives outside the router's own build scope.
final currentPathProvider = StateProvider<String>((ref) => '/');

final recentModuleProvider = StateProvider<String?>((ref) => null);
