import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
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
import '../../features/profile/presentation/change_password_screen.dart';
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
import '../../features/community/data/community_repository.dart';
import '../../features/community/presentation/community_hub_screen.dart';
import '../../features/community/presentation/post_compose_screen.dart';
import '../../features/community/presentation/post_detail_screen.dart';
import '../../features/community/presentation/posts_screen.dart';
import '../../features/community/presentation/testimonial_compose_screen.dart';
import '../../features/community/presentation/testimonials_screen.dart';
import '../../features/counseling/presentation/counseling_screen.dart';
import '../../features/donation/presentation/donation_screen.dart';
import '../../features/learning/presentation/learning_certificates_screen.dart';
import '../../features/learning/presentation/learning_course_detail_screen.dart';
import '../../features/learning/presentation/learning_courses_screen.dart';
import '../../features/learning/presentation/learning_lesson_screen.dart';
import '../../features/learning/presentation/learning_my_courses_screen.dart';
import '../../features/learning/presentation/learning_quiz_screen.dart';
import '../../features/quran_live/presentation/quran_hub_screen.dart';
import '../../features/quran_live/presentation/quran_live_admission_screen.dart';
import '../../features/quran_live/presentation/quran_live_course_detail_screen.dart';
import '../../features/quran_live/presentation/quran_live_courses_screen.dart';
import '../../features/quran_live/presentation/quran_live_my_class_screen.dart';
import '../../features/quran_live/presentation/quran_live_my_progress_screen.dart';
import '../../features/quran_live/presentation/quran_live_subscribe_screen.dart';
import '../../features/volunteer/presentation/volunteer_screen.dart';
import '../../features/wall/presentation/wall_screen.dart';
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

      const guestOnly = ['/language', '/welcome', '/login', '/register', '/otp', '/forgot-password'];
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
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: '/change-password', builder: (context, state) => const ChangePasswordScreen()),
      GoRoute(
        path: '/faq/:module',
        builder: (context, state) => FaqScreen(module: state.pathParameters['module']!),
      ),
      GoRoute(path: '/nikah', builder: (context, state) => const NikahHomeScreen()),
      GoRoute(path: '/volunteer', builder: (context, state) => const VolunteerScreen()),
      GoRoute(path: '/donate', builder: (context, state) => const DonationScreen()),
      GoRoute(path: '/wall', builder: (context, state) => const WallScreen()),
      GoRoute(path: '/counseling', builder: (context, state) => const CounselingScreen()),
      GoRoute(path: '/quran-hub', builder: (context, state) => const QuranHubScreen()),
      GoRoute(path: '/quran-live', builder: (context, state) => const QuranLiveCoursesScreen()),
      GoRoute(path: '/quran-live/my-class', builder: (context, state) => const QuranLiveMyClassScreen()),
      GoRoute(
        path: '/quran-live/my-progress',
        builder: (context, state) {
          final child = state.uri.queryParameters['child'];
          return QuranLiveMyProgressScreen(childId: child != null ? int.tryParse(child) : null);
        },
      ),
      GoRoute(
        path: '/quran-live/:id',
        builder: (context, state) => QuranLiveCourseDetailScreen(courseId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/quran-live/:id/admission',
        builder: (context, state) => QuranLiveAdmissionScreen(courseId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/quran-live/:id/subscribe/:admissionId',
        builder: (context, state) => QuranLiveSubscribeScreen(
          courseId: int.parse(state.pathParameters['id']!),
          admissionId: int.parse(state.pathParameters['admissionId']!),
        ),
      ),
      // Community — member-authored posts (gated to accounts with
      // posts.manage/admin — see AppUser.canWritePosts) and testimonials,
      // open to everyone. Blog was dropped from the app entirely; common
      // members' only posting surface is the Wall. The compose routes take
      // the item being edited via `extra` rather than refetching it by id:
      // the caller already has it, and passing it keeps the form from
      // flashing empty while a redundant request lands.
      GoRoute(path: '/community', builder: (context, state) => const CommunityHubScreen()),
      GoRoute(path: '/community/posts', builder: (context, state) => const PostsScreen()),
      GoRoute(
        path: '/community/posts/compose',
        builder: (context, state) => PostComposeScreen(existing: state.extra as MemberPost?),
      ),
      GoRoute(
        path: '/community/posts/:id',
        builder: (context, state) => PostDetailScreen(postId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/community/testimonials', builder: (context, state) => const TestimonialsScreen()),
      GoRoute(
        path: '/community/testimonials/compose',
        builder: (context, state) => TestimonialComposeScreen(existing: state.extra as MemberTestimonial?),
      ),

      // Self-paced learning. Each segment after /learning is a distinct
      // static prefix (track/course/lesson/...) rather than a bare
      // '/learning/:something', so no route can shadow another regardless of
      // declaration order.
      GoRoute(path: '/learning/my-courses', builder: (context, state) => const LearningMyCoursesScreen()),
      GoRoute(path: '/learning/certificates', builder: (context, state) => const LearningCertificatesScreen()),
      GoRoute(
        path: '/learning/track/:track',
        builder: (context, state) => LearningCoursesScreen(trackKey: state.pathParameters['track']!),
      ),
      GoRoute(
        path: '/learning/course/:id',
        builder: (context, state) => LearningCourseDetailScreen(courseId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/learning/course/:id/quiz',
        builder: (context, state) => LearningQuizScreen(
          ownerId: int.parse(state.pathParameters['id']!),
          isFinal: true,
          trackKey: state.uri.queryParameters['track'] ?? 'quran',
        ),
      ),
      GoRoute(
        path: '/learning/lesson/:id',
        builder: (context, state) => LearningLessonScreen(lessonId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/learning/lesson/:id/quiz',
        builder: (context, state) => LearningQuizScreen(
          ownerId: int.parse(state.pathParameters['id']!),
          isFinal: false,
          trackKey: state.uri.queryParameters['track'] ?? 'quran',
        ),
      ),
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
