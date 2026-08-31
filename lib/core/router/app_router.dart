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
import '../../features/nikah/presentation/nikah_blocked_screen.dart';
import '../../features/nikah/presentation/nikah_browse_screen.dart';
import '../../features/nikah/presentation/nikah_counselor_chat_screen.dart';
import '../../features/nikah/presentation/nikah_counselor_picker_screen.dart';
import '../../features/nikah/presentation/nikah_hire_package_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/nikah/presentation/nikah_home_screen.dart';
import '../../features/nikah/presentation/nikah_interests_screen.dart';
import '../../features/nikah/presentation/nikah_messages_screen.dart';
import '../../features/nikah/presentation/nikah_payment_screen.dart';
import '../../features/nikah/presentation/nikah_profile_detail_screen.dart';
import '../../features/nikah/presentation/nikah_saved_screen.dart';
import '../../features/nikah/presentation/wizard/nikah_review_screen.dart';
import '../../features/nikah/presentation/wizard/nikah_step1_screen.dart';
import '../../features/nikah/presentation/wizard/nikah_step2_screen.dart';
import '../../features/nikah/presentation/wizard/nikah_step3_screen.dart';
import '../../features/nikah/presentation/wizard/nikah_step4_screen.dart';
import '../../features/donation/presentation/donation_screen.dart';
import '../../features/volunteer/presentation/volunteer_screen.dart';
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
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(
        path: '/faq/:module',
        builder: (context, state) => FaqScreen(module: state.pathParameters['module']!),
      ),
      GoRoute(path: '/nikah', builder: (context, state) => const NikahHomeScreen()),
      GoRoute(path: '/volunteer', builder: (context, state) => const VolunteerScreen()),
      GoRoute(path: '/donate', builder: (context, state) => const DonationScreen()),
      GoRoute(path: '/nikah/wizard/step1', builder: (context, state) => const NikahStep1Screen()),
      GoRoute(path: '/nikah/wizard/step2', builder: (context, state) => const NikahStep2Screen()),
      GoRoute(path: '/nikah/wizard/step3', builder: (context, state) => const NikahStep3Screen()),
      GoRoute(path: '/nikah/wizard/step4', builder: (context, state) => const NikahStep4Screen()),
      GoRoute(path: '/nikah/wizard/review', builder: (context, state) => const NikahReviewScreen()),
      GoRoute(path: '/nikah/payment', builder: (context, state) => const NikahPaymentScreen()),
      GoRoute(path: '/nikah/browse', builder: (context, state) => const NikahBrowseScreen()),
      GoRoute(path: '/nikah/interests', builder: (context, state) => const NikahInterestsScreen()),
      GoRoute(path: '/nikah/saved', builder: (context, state) => const NikahSavedScreen()),
      GoRoute(path: '/nikah/blocked', builder: (context, state) => const NikahBlockedScreen()),
      GoRoute(path: '/nikah/counselor/pick', builder: (context, state) => const NikahCounselorPickerScreen()),
      GoRoute(path: '/nikah/counselor/package', builder: (context, state) => const NikahHirePackageScreen()),
      GoRoute(
        path: '/nikah/counselor/chat/:leadId',
        builder: (context, state) => NikahCounselorChatScreen(leadId: int.parse(state.pathParameters['leadId']!)),
      ),
      GoRoute(
        path: '/nikah/profile/:id',
        builder: (context, state) => NikahProfileDetailScreen(profileId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/nikah/interests/:interestId/messages',
        builder: (context, state) => NikahMessagesScreen(interestId: int.parse(state.pathParameters['interestId']!)),
      ),
    ],
  );
});
