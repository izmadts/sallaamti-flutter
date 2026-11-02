import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../features/auth/state/auth_controller.dart';

class AppUpdateStatus {
  final bool updateRequired;
  final String? updateUrl;
  const AppUpdateStatus({required this.updateRequired, this.updateUrl});
}

// Checked once by SplashScreen before it routes anywhere else — a hard
// gate, not a dismissible "new version available" nudge (that's a
// different, lower-stakes feature this isn't trying to be). Fails open on
// any error (network down, backend unreachable, endpoint missing on an
// older backend): the app must never lock every user out just because this
// one check couldn't complete.
final appUpdateProvider = FutureProvider<AppUpdateStatus>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(info.buildNumber) ?? 0;

    final client = ref.read(apiClientProvider);
    final data = await client.get('/meta/app-version', query: {'app': 'member'});

    final minimumBuild = data['minimum_build_number'] as int?;
    if (minimumBuild != null && currentBuild > 0 && currentBuild < minimumBuild) {
      return AppUpdateStatus(updateRequired: true, updateUrl: data['update_url'] as String?);
    }
  } catch (_) {
    // Fall through to "no update required" below.
  }

  return const AppUpdateStatus(updateRequired: false);
});
