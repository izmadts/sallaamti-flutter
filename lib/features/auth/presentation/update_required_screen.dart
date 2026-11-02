import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/module_themes.dart';

// Reached only from SplashScreen, when appUpdateProvider says the installed
// build is below the admin-set minimum — deliberately has no back button
// and no way to reach the rest of the app, same reasoning as every other
// hard gate in this app (maintenance mode, deactivated account): an
// outdated build may have a real, already-known bug, so the uncertainty of
// "let them keep using it" is worse than briefly inconveniencing everyone.
class UpdateRequiredScreen extends StatelessWidget {
  final String? updateUrl;
  const UpdateRequiredScreen({super.key, this.updateUrl});

  Future<void> _openStore(BuildContext context) async {
    if (updateUrl == null) return;
    final uri = Uri.tryParse(updateUrl!);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the Play Store — please update manually from there.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.logoBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('⬆️', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 24),
                  const Text(
                    'A New Version is Available',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please update Sallaamti to keep using the app — this version is no longer supported.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _openStore(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.logoBackground,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
