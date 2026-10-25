import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/router/app_router.dart';
import '../../core/state/locale_controller.dart';
import '../../core/state/navigation_state.dart';
import '../../features/auth/state/auth_controller.dart';
import '../../features/dashboard/data/dashboard_repository.dart';
import '../../features/profile/presentation/account_sheet.dart';
import '../../l10n/generated/app_localizations.dart';
import '../modules.dart';
import 'whatsapp_channel_action.dart';

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
    // Visibility lives here (reactive, via ref.watch) rather than being
    // decided once in main.dart and baked into an Overlay/OverlayEntry
    // closure — that outer wrapper's shape needs to stay fixed across
    // rebuilds (see main.dart's comment on why), so it always includes
    // this widget and lets it decide for itself whether to render anything.
    final isAuthenticated =
        ref.watch(authControllerProvider).status == AuthStatus.authenticated;
    if (!isAuthenticated) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final currentPath = ref.watch(currentPathProvider);
    final recentModule =
        ref.watch(recentModuleProvider) ?? _fallbackRecentModule;
    // Pre-warms the fetch as soon as the member is logged in, rather than
    // only starting it the moment they tap More — _MoreSheet watches this
    // same provider itself (see below) instead of receiving a value handed
    // to it here, since a value captured at tap-time stays frozen at
    // whatever it was that instant (often still "loading") for the sheet's
    // entire lifetime, which is exactly what made WhatsApp support/report
    // look permanently broken if tapped before this fetch had resolved.
    ref.watch(dashboardMetaProvider);

    final isHome = currentPath == '/dashboard';
    final isWall = currentPath == '/wall';
    final isRecentModule =
        !isHome && !isWall && moduleForPath(currentPath) == recentModule;

    // Index is purely for NavigationBar's own highlight bookkeeping — the
    // real "what's active" answer is currentPath above, so None-of-the-
    // above (a deep detail screen) just leaves every tab unselected rather
    // than forcing one to light up incorrectly.
    final selectedIndex = isHome ? 0 : (isWall ? 1 : (isRecentModule ? 2 : -1));

    // AppBottomNav sits in the outer Scaffold's bottomNavigationBar slot,
    // a SIBLING of body (and therefore of GoRouter's own Navigator) in the
    // widget tree — not a descendant. context.go()/push() walk ancestors
    // looking for a GoRouter to talk to and find none from here, so this
    // goes straight to the router instance instead (see rootNavigatorKey's
    // docs in app_router.dart for the full story and why this was
    // completely silent: the resulting error got lost inside Flutter's own
    // error-report renderer rather than surfacing as a visible crash).
    final router = ref.read(routerProvider);

    return NavigationBar(
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            router.go('/dashboard');
          case 1:
            router.go('/wall');
          case 2:
            final route = moduleRoute(recentModule);
            if (route != null) router.push(route);
          case 3:
            _openMoreSheet();
        }
      },
      destinations: [
        NavigationDestination(
          icon: const Text('🏠', style: TextStyle(fontSize: 20)),
          label: l10n.navHome,
        ),
        NavigationDestination(
          icon: Text(
            moduleEmoji['wall'] ?? '📣',
            style: const TextStyle(fontSize: 20),
          ),
          label: moduleShortLabel(context, 'wall'),
        ),
        NavigationDestination(
          icon: Text(
            moduleEmoji[recentModule] ?? '⭐',
            style: const TextStyle(fontSize: 20),
          ),
          label: moduleShortLabel(context, recentModule),
        ),
        NavigationDestination(
          icon: const Icon(Icons.grid_view_rounded),
          label: l10n.navMore,
        ),
      ],
    );
  }

  void _openMoreSheet() {
    // rootNavigatorKey's context, not AppBottomNav's own — see the comment
    // in build() above.
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null) return;

    showModalBottomSheet(
      context: navigatorContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => const _MoreSheet(),
    );
  }
}

class _MoreSheet extends ConsumerWidget {
  const _MoreSheet();

  Future<void> _openWhatsapp(
    BuildContext context,
    WidgetRef ref,
    String message,
  ) async {
    // Watched fresh at tap-time (not passed in from outside) so a slow
    // first fetch doesn't leave this permanently stuck on "not set up yet"
    // — see AppBottomNav's pre-warming comment for the full story.
    final number = ref.read(dashboardMetaProvider).valueOrNull?.whatsappNumber;
    if (number == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support contact is not set up yet.')),
      );
      return;
    }
    final uri = Uri.parse(
      'https://wa.me/$number?text=${Uri.encodeComponent(message)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
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
    final meta = ref.watch(dashboardMetaProvider).valueOrNull;
    final modules = (meta?.modules ?? [])
        .where((m) => m != 'wall' && m != recentModule)
        .toList();

    return SafeArea(
      // The plain Column below overflowed off the bottom of the screen once
      // the module grid plus every list tile (Notifications through Report
      // a Problem) added up to more height than the screen had — silently
      // making WhatsApp Support/Report a Problem unreachable rather than
      // "not working" in any way visible in a release build. Capping at
      // 85% of the screen and making it scrollable fixes that regardless of
      // how many modules a given member has enabled.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
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
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (modules.isNotEmpty) ...[
                  const Text(
                    'More Modules',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
                  label: isUrdu
                      ? 'زبان: اردو (Switch to English)'
                      : 'Language: English (Switch to Urdu)',
                  onTap: () => ref
                      .read(localeControllerProvider.notifier)
                      .choose(isUrdu ? 'en' : 'ur'),
                ),
                _MoreTile(
                  icon: Icons.help_outline,
                  label: 'FAQ',
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push('/faq/general');
                  },
                ),
                const Divider(height: 24),
                _MoreTile(
                  leadingWidget: const WhatsappBadge(),
                  label: 'Instant Support (WhatsApp)',
                  onTap: () {
                    Navigator.of(context).pop();
                    _openWhatsapp(
                      context,
                      ref,
                      'Assalam-o-Alaikum, I need help with the Sallaamti app.',
                    );
                  },
                ),
                _MoreTile(
                  icon: Icons.flag_outlined,
                  iconColor: Colors.orange.shade700,
                  label: 'Report a Problem',
                  onTap: () {
                    Navigator.of(context).pop();
                    _openWhatsapp(
                      context,
                      ref,
                      'Assalam-o-Alaikum, I\'d like to report a problem in the Sallaamti app:',
                    );
                  },
                ),
                const Divider(height: 24),
                const Text(
                  'Follow Us',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 12),
                _FollowUsRow(meta: meta),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// WhatsApp Channel is always shown (fixed link, not settings-driven); the
// other four only appear once configured in admin Settings, so the app
// never shows an icon that would lead nowhere — see DashboardController's
// 'social' block.
class _FollowUsRow extends StatelessWidget {
  final DashboardMeta? meta;
  const _FollowUsRow({required this.meta});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      children: [
        _SocialIcon(
          badge: const WhatsappBadge(size: 40),
          tooltip: 'Join our WhatsApp Channel',
          onTap: () => openWhatsappChannel(context),
        ),
        if ((meta?.facebookUrl ?? '').isNotEmpty)
          _SocialIcon(
            badge: const _SocialBadge(icon: Icons.facebook, color: Color(0xFF1877F2)),
            tooltip: 'Facebook',
            onTap: () => _openSocialLink(context, meta!.facebookUrl!),
          ),
        if ((meta?.instagramUrl ?? '').isNotEmpty)
          _SocialIcon(
            badge: const _SocialBadge(icon: Icons.camera_alt, color: Color(0xFFE1306C)),
            tooltip: 'Instagram',
            onTap: () => _openSocialLink(context, meta!.instagramUrl!),
          ),
        if ((meta?.youtubeUrl ?? '').isNotEmpty)
          _SocialIcon(
            badge: const _SocialBadge(icon: Icons.smart_display, color: Color(0xFFFF0000)),
            tooltip: 'YouTube',
            onTap: () => _openSocialLink(context, meta!.youtubeUrl!),
          ),
        if ((meta?.tiktokUrl ?? '').isNotEmpty)
          _SocialIcon(
            badge: const _SocialBadge(icon: Icons.music_note, color: Colors.black),
            tooltip: 'TikTok',
            onTap: () => _openSocialLink(context, meta!.tiktokUrl!),
          ),
      ],
    );
  }
}

Future<void> _openSocialLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that link.')),
      );
    }
  }
}

class _SocialIcon extends StatelessWidget {
  final Widget badge;
  final String tooltip;
  final VoidCallback onTap;
  const _SocialIcon({required this.badge, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: badge,
      ),
    );
  }
}

// Same "colored circle + close-enough Material icon" convention as
// WhatsappBadge — no brand-icon package needed (font_awesome_flutter's
// IconData subclasses don't compile against this SDK).
class _SocialBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _SocialBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 22),
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
          Text(
            moduleEmoji[module] ?? '⭐',
            style: const TextStyle(fontSize: 28),
          ),
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
  final IconData? icon;
  final Color? iconColor;
  // Overrides `icon`/`iconColor` for a leading glyph that isn't a plain
  // IconData — e.g. WhatsappBadge's colored circle.
  final Widget? leadingWidget;
  final String label;
  final VoidCallback onTap;
  const _MoreTile({
    this.icon,
    this.iconColor,
    this.leadingWidget,
    required this.label,
    required this.onTap,
  }) : assert(icon != null || leadingWidget != null);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: leadingWidget ?? Icon(icon, color: iconColor),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}
