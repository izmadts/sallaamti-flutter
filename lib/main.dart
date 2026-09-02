import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push/push_notification_service.dart';
import 'core/router/app_router.dart';
import 'core/state/locale_controller.dart';
import 'core/theme/module_themes.dart';
import 'l10n/generated/app_localizations.dart';
import 'shared/widgets/app_bottom_nav.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await initLocalNotifications();
  runApp(const ProviderScope(child: SallaamtiApp()));
}

class SallaamtiApp extends ConsumerWidget {
  const SallaamtiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeControllerProvider);

    return MaterialApp.router(
      title: 'Sallaamti',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.base,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      // A single global bottom nav for the whole authenticated app, rather
      // than each screen wiring up its own — nests happily inside every
      // route's own Scaffold (only the AppBar/body area shrinks; Flutter
      // already excludes the bottom inset from what's passed down to body
      // once an outer Scaffold owns a bottomNavigationBar, so inner screens'
      // own SafeAreas don't double-pad). AppBottomNav hides itself (renders
      // SizedBox.shrink) before login — that decision lives inside the
      // widget, reactive via ref.watch, NOT here: this builder's own shape
      // must stay fixed across rebuilds (see the Overlay note below), so it
      // always includes AppBottomNav unconditionally and lets it decide.
      //
      // This Scaffold's bottomNavigationBar slot is a SIBLING of `child`
      // (and therefore of GoRouter's own Navigator/Overlay) in the widget
      // tree, not a descendant — so anything placed there that needs an
      // Overlay (NavigationBar's destinations wrap themselves in Tooltip,
      // which requires one) or a Navigator (showModalBottomSheet) finds
      // neither by walking ancestors from its own context. The Overlay
      // below supplies that missing ancestor for real; AppBottomNav itself
      // sidesteps the Navigator/GoRouter gap by using the router instance
      // directly (ref.read(routerProvider)) and rootNavigatorKey's context
      // rather than context.go()/push() or its own context — see that
      // file's comments for the full story.
      builder: (context, child) {
        return Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => Scaffold(
                body: child,
                bottomNavigationBar: const AppBottomNav(),
              ),
            ),
          ],
        );
      },
    );
  }
}
