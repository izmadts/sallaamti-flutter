import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/modules.dart';
import '../../../shared/widgets/authed_avatar.dart';
import '../../../shared/widgets/language_switch_button.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../auth/state/auth_controller.dart';
import '../../profile/presentation/account_sheet.dart';
import '../../profile/presentation/edit_profile_screen.dart';
import '../data/dashboard_repository.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _bindNudgeDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptPasswordChange());
  }

  void _maybePromptPasswordChange() {
    final user = ref.read(authControllerProvider).user;
    if (user == null || !user.mustChangePassword || !mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Your Own Password'),
        content: Text(
          user.hasRealPassword
              ? 'Your Nikah Counselor set up a temporary password for you. For your account\'s security, please choose your own password.'
              : 'For your account\'s security, please set a password — you can then log in with it any time, using either your phone number or email.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Ignore')),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/change-password');
            },
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final metaAsync = ref.watch(dashboardMetaProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Image.asset('assets/app-logo.png', height: 34),
        actions: [
          const NotificationBell(),
          const LanguageSwitchButton(),
          IconButton(
            icon: AuthedAvatar(
              url: user?.avatarUrl,
              radius: 15,
              backgroundColor: Colors.white24,
              fallback: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
            tooltip: 'Account',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => const AccountSheet(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.dashboardWelcome(user?.name ?? ''),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(l10n.modulesTitle, style: TextStyle(color: Colors.grey.shade600)),
              if (!_bindNudgeDismissed && user != null && (user.phone == null || user.email == null)) ...[
                const SizedBox(height: 16),
                _BindIdentifierBanner(
                  missingPhone: user.phone == null,
                  onDismiss: () => setState(() => _bindNudgeDismissed = true),
                ),
              ],
              const SizedBox(height: 20),
              Expanded(
                child: metaAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) {
                    final message = error is ApiException ? error.message : l10n.errorGeneric;
                    return Center(child: Text(message, textAlign: TextAlign.center));
                  },
                  data: (meta) => GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: meta.modules.length,
                    itemBuilder: (context, index) => _ModuleTile(module: meta.modules[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// A phone-only or email-only account is how two separate accounts for the
// same person end up getting created later — e.g. registering with
// email+password once, then with phone+OTP another time, with no way for
// either to know about the other. Closing the gap right after signup is
// the real fix; dismissible per visit (resets next time the screen loads,
// same as the password-nudge dialog reappearing).
class _BindIdentifierBanner extends StatelessWidget {
  final bool missingPhone;
  final VoidCallback onDismiss;
  const _BindIdentifierBanner({required this.missingPhone, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.blue.shade50,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Text('🔗', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    missingPhone ? 'Add your mobile number' : 'Add your email address',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'So you can always log in with either one, and so you never end up with two separate accounts.',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                      child: const Text('Add Now'),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: Colors.blueGrey,
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final String module;
  const _ModuleTile({required this.module});

  @override
  Widget build(BuildContext context) {
    final color = ModuleThemes.seedFor(module);
    final l10n = AppLocalizations.of(context)!;
    final route = moduleRoute(module);

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      shadowColor: color.withValues(alpha: 0.4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => route != null
            ? context.push(route)
            : ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.comingSoon))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(moduleEmoji[module] ?? '⭐', style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 10),
              Text(
                moduleLabel(context, module),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
