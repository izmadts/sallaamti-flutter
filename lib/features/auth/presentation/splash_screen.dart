import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/locale_controller.dart';
import '../../../core/theme/module_themes.dart';
import '../../../core/update/app_version_checker.dart';
import '../state/auth_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeControllerProvider);
    final localeRestored = ref.watch(localeRestoredProvider);
    final auth = ref.watch(authControllerProvider);
    final updateStatus = ref.watch(appUpdateProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Checked before anything else, logged in or not — still loading is
      // treated as "wait" rather than "no update needed" so a slow network
      // never lets someone slip past into the app with a flash first, and
      // the provider itself fails open on any error so a check that can't
      // complete doesn't block forever either.
      if (updateStatus.isLoading) return;
      if (updateStatus.valueOrNull?.updateRequired == true) {
        context.go('/update-required', extra: updateStatus.value!.updateUrl);
        return;
      }

      // Still reading from storage — wait for the rebuild this triggers
      // once it resolves, rather than treating "not checked yet" the same
      // as "checked, no saved locale."
      if (!localeRestored) return;

      if (locale == null) {
        context.go('/language');
        return;
      }

      if (auth.status == AuthStatus.authenticated) {
        context.go('/dashboard');
      } else if (auth.status == AuthStatus.unauthenticated) {
        context.go('/welcome');
      }
    });

    return Scaffold(
      // Matches the native launch screen's background so control passing
      // from it to this widget doesn't flash a different color first.
      backgroundColor: AppTheme.logoBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: 'Sallaamti',
              child: Image.asset('assets/icon.png', width: 220),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
