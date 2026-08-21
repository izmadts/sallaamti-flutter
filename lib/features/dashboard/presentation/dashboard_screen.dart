import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/language_switch_button.dart';
import '../../auth/state/auth_controller.dart';

const _moduleEmoji = {
  'nikah': '💍',
  'quran': '📖',
  'quran_live': '🕌',
  'skills': '💻',
  'counseling': '🤝',
  'donation': '💝',
  'volunteer': '🙌',
  'wall': '📣',
};

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late Future<List<String>> _modulesFuture;

  @override
  void initState() {
    super.initState();
    _modulesFuture = _loadModules();
  }

  Future<List<String>> _loadModules() async {
    final client = ref.read(apiClientProvider);
    final data = await client.get('/dashboard');
    return (data['modules'] as List).map((e) => e.toString()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/app-logo.png', height: 34),
        actions: [
          const LanguageSwitchButton(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.logout,
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
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
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<String>>(
                  future: _modulesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      final message = snapshot.error is ApiException
                          ? (snapshot.error as ApiException).message
                          : l10n.errorGeneric;
                      return Center(child: Text(message, textAlign: TextAlign.center));
                    }

                    final modules = snapshot.data ?? [];

                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.05,
                      ),
                      itemCount: modules.length,
                      itemBuilder: (context, index) {
                        final module = modules[index];
                        return _ModuleTile(module: module);
                      },
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: () => context.push('/faq/general'),
                child: Text(l10n.faqTitle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final String module;
  const _ModuleTile({required this.module});

  String _label(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (module) {
      'nikah' => l10n.moduleNikah,
      'quran' => l10n.moduleQuran,
      'quran_live' => l10n.moduleQuranLive,
      'skills' => l10n.moduleSkills,
      'counseling' => l10n.moduleCounseling,
      'donation' => l10n.moduleDonation,
      'volunteer' => l10n.moduleVolunteer,
      'wall' => l10n.moduleWall,
      _ => module,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = ModuleThemes.seedFor(module);
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => module == 'nikah'
            ? context.push('/nikah')
            : ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.comingSoon))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_moduleEmoji[module] ?? '⭐', style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 10),
              Text(
                _label(context),
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.9)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
