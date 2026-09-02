import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push/push_notification_service.dart';
import 'core/router/app_router.dart';
import 'core/state/locale_controller.dart';
import 'core/theme/module_themes.dart';
import 'features/auth/state/auth_controller.dart';
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
    final isAuthenticated = ref.watch(authControllerProvider).status == AuthStatus.authenticated;

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
      // own SafeAreas don't double-pad). Hidden before login since none of
      // Home/Wall/module/More make sense pre-auth.
      builder: (context, child) {
        return Scaffold(
          body: child,
          bottomNavigationBar: isAuthenticated ? const AppBottomNav() : null,
        );
      },
    );
  }
}
