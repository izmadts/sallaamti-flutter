import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_controller.dart';

class DashboardMeta {
  final List<String> modules;
  final String? whatsappNumber;
  const DashboardMeta({required this.modules, this.whatsappNumber});
}

// Shared across DashboardScreen's own grid and the global bottom nav's
// "More" sheet (which lives outside the dashboard route entirely, so it
// can't just read DashboardScreen's local state) — one fetch, cached by
// Riverpod, instead of every consumer hitting /dashboard separately.
final dashboardMetaProvider = FutureProvider<DashboardMeta>((ref) async {
  final client = ref.read(apiClientProvider);
  final data = await client.get('/dashboard');

  final modules = (data['modules'] as List).map((e) => e.toString()).toList();
  // 'quran' and 'quran_live' are two different backend systems gated by the
  // same toggle, but share one dashboard tile — 'quran' opens a chooser
  // (QuranHubScreen) between Live Classes and Self-Paced Learning, so
  // 'quran_live' never needs its own tile.
  final tileModules = modules.where((m) => m != 'quran_live').toList();

  final support = data['support'] as Map?;

  return DashboardMeta(
    modules: tileModules,
    whatsappNumber: support?['whatsapp_number'] as String?,
  );
});
