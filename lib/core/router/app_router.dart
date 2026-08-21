import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/language_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/auth/state/auth_controller.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/faq/presentation/faq_screen.dart';
import '../state/locale_controller.dart';

// A tiny ChangeNotifier bridge so GoRouter's redirect re-evaluates whenever
// auth or locale state changes, without recreating the router (which would
// lose the navigation stack) on every rebuild.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
    ref.listen(localeControllerProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final locale = ref.read(localeControllerProvider);
      final auth = ref.read(authControllerProvider);
      final path = state.matchedLocation;

      if (path == '/') return null; // splash decides the first hop itself

      if (locale == null) return '/language';

      const guestOnly = ['/language', '/welcome', '/login', '/register', '/otp'];
      final isGuestOnlyRoute = guestOnly.contains(path);

      if (auth.status == AuthStatus.checking) return null;

      if (auth.status == AuthStatus.unauthenticated && !isGuestOnlyRoute) {
        return '/welcome';
      }

      if (auth.status == AuthStatus.authenticated && isGuestOnlyRoute && path != '/language') {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/language', builder: (context, state) => const LanguageScreen()),
      GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/otp', builder: (context, state) => const OtpScreen()),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
      GoRoute(
        path: '/faq/:module',
        builder: (context, state) => FaqScreen(module: state.pathParameters['module']!),
      ),
    ],
  );
});
