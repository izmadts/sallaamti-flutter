import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/state/locale_controller.dart';
import '../../core/state/navigation_state.dart';
import '../../features/dashboard/data/dashboard_repository.dart';
import '../../features/profile/presentation/account_sheet.dart';
import '../modules.dart';

// The app's global bottom nav — added once, at the MaterialApp.router level
// (see main.dart), so it's present on every authenticated screen rather
// than something each screen has to remember to include. Home and Wall are
// fixed; the 3rd tab dynamically follows whichever module the member most
// recently opened (recentModuleProvider, updated by app_router.dart's
// redirect); More holds everything else — the remaining modules plus
// account-level actions that don't belong on any single module's own
// screen (language, notifications, support).
class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({super.key});

  static const _fallbackRecentModule = 'nikah';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = ref.watch(currentPathProvider);
    final recentModule = ref.watch(recentModuleProvider) ?? _fallbackRecentModule;
    final metaAsync = ref.watch(dashboardMetaProvider);

    final isHome = currentPath == '/dashboard';
    final isWall = currentPath == '/wall';
    final isRecentModule = !isHome && !isWall && moduleForPath(currentPath) == recentModule;

    return Material(
      elevation: 12,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _NavItem(
                emoji: '🏠',
                label: 'Home',
                active: isHome,
                onTap: () => context.go('/dashboard'),
              ),
              _NavItem(
                emoji: moduleEmoji['wall'] ?? '📣',
                label: 'Wall',
                active: isWall,
                onTap: () => context.go('/wall'),
              ),
              _NavItem(
                emoji: moduleEmoji[recentModule] ?? '⭐',
                label: moduleLabel(context, recentModule),
                active: isRecentModule,
                onTap: () {
                  final route = moduleRoute(recentModule);
                  if (route != null) context.push(route);
                },
              ),
              _NavItem(
                icon: Icons.grid_view_rounded,
                label: 'More',
                active: false,
                onTap: () => _openMoreSheet(context, ref, metaAsync.valueOrNull),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMoreSheet(BuildContext context, WidgetRef ref, DashboardMeta? meta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => _MoreSheet(meta: meta),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String? emoji;
  final IconData? icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({this.emoji, this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? Theme.of(context).colorScheme.primary : Colors.grey.shade500;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (emoji != null)
              Text(emoji!, style: TextStyle(fontSize: active ? 22 : 20))
            else
              Icon(icon, size: active ? 24 : 22, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreSheet extends ConsumerWidget {
  final DashboardMeta? meta;
  const _MoreSheet({required this.meta});

  Future<void> _openWhatsapp(BuildContext context, String message) async {
    final number = meta?.whatsappNumber;
    if (number == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support contact is not set up yet.')));
      return;
    }
    final uri = Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(message)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    final isUrdu = locale?.languageCode == 'ur';

    // Home and Wall already have their own permanent tabs; the recent-module
    // tab covers whichever module the member is mid-journey with — this
    // grid is everything else, so nothing enabled ends up unreachable once
    // it scrolls off the recent-module slot.
    final recentModule = ref.watch(recentModuleProvider);
    final modules = (meta?.modules ?? [])
        .where((m) => m != 'wall' && m != recentModule)
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            if (modules.isNotEmpty) ...[
              const Text('More Modules', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemCount: modules.length,
                itemBuilder: (context, index) {
                  final module = modules[index];
                  return _MoreModuleTile(module: module);
                },
              ),
              const SizedBox(height: 8),
              const Divider(height: 24),
            ],
            _MoreTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () {
                Navigator.of(context).pop();
                context.push('/notifications');
              },
            ),
            _MoreTile(
              icon: Icons.account_circle_outlined,
              label: 'My Account',
              onTap: () {
                Navigator.of(context).pop();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => const AccountSheet(),
                );
              },
            ),
            _MoreTile(
              icon: Icons.language,
              label: isUrdu ? 'زبان: اردو (Switch to English)' : 'Language: English (Switch to Urdu)',
              onTap: () => ref.read(localeControllerProvider.notifier).choose(isUrdu ? 'en' : 'ur'),
            ),
            const Divider(height: 24),
            _MoreTile(
              icon: Icons.chat_bubble_outline,
              iconColor: const Color(0xFF25D366),
              label: 'Instant Support (WhatsApp)',
              onTap: () {
                Navigator.of(context).pop();
                _openWhatsapp(context, 'Assalam-o-Alaikum, I need help with the Sallaamti app.');
              },
            ),
            _MoreTile(
              icon: Icons.flag_outlined,
              iconColor: Colors.orange.shade700,
              label: 'Report a Problem',
              onTap: () {
                Navigator.of(context).pop();
                _openWhatsapp(context, 'Assalam-o-Alaikum, I\'d like to report a problem in the Sallaamti app:');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreModuleTile extends StatelessWidget {
  final String module;
  const _MoreModuleTile({required this.module});

  @override
  Widget build(BuildContext context) {
    final route = moduleRoute(module);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: route == null
          ? null
          : () {
              Navigator.of(context).pop();
              context.push(route);
            },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(moduleEmoji[module] ?? '⭐', style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(
            moduleLabel(context, module),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final VoidCallback onTap;
  const _MoreTile({required this.icon, this.iconColor, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}
