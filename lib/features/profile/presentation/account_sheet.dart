import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/authed_avatar.dart';
import '../../auth/state/auth_controller.dart';
import '../../donation/presentation/donation_history_screen.dart';
import 'edit_profile_screen.dart';

class AccountSheet extends ConsumerWidget {
  const AccountSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AuthedAvatar(
                  url: user?.avatarUrl,
                  radius: 28,
                  backgroundColor: Colors.teal.withValues(alpha: 0.1),
                  fallback: const Icon(Icons.person),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      if ((user?.email ?? '').isNotEmpty)
                        Text(user!.email!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            _MenuTile(
              icon: Icons.person_outline,
              label: 'Edit Profile',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
              },
            ),
            _MenuTile(
              icon: Icons.volunteer_activism_outlined,
              label: 'My Donations',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DonationHistoryScreen()));
              },
            ),
            if (user?.hasNikahProfile ?? false) ...[
              _MenuTile(
                icon: Icons.favorite_border,
                label: 'My Interests',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/nikah/interests');
                },
              ),
              _MenuTile(
                icon: Icons.star_border,
                label: 'Saved Profiles',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/nikah/saved');
                },
              ),
            ],
            const Divider(height: 1),
            _MenuTile(
              icon: Icons.logout,
              label: 'Log Out',
              color: Colors.red.shade600,
              onTap: () {
                Navigator.of(context).pop();
                ref.read(authControllerProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _MenuTile({required this.icon, required this.label, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}
