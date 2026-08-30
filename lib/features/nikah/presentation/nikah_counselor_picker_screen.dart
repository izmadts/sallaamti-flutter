import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/nikah_hire_repository.dart';

const _tierBadges = {
  'nikah_counselor': '🥉',
  'certified_nikah_counselor': '🥈',
  'senior_nikah_counselor': '🥇',
  'regional_nikah_coordinator': '⭐',
};

// Entry point is nikah_home_screen.dart's optional "Bring in a Nikah
// Counselor" tile — never forced. Picking someone here creates (or
// reassigns) a Lead behind the scenes; from that point on this member is
// a normal client in that counselor's existing CRM.
class NikahCounselorPickerScreen extends ConsumerStatefulWidget {
  const NikahCounselorPickerScreen({super.key});

  @override
  ConsumerState<NikahCounselorPickerScreen> createState() => _NikahCounselorPickerScreenState();
}

class _NikahCounselorPickerScreenState extends ConsumerState<NikahCounselorPickerScreen> {
  List<NikahCounselor> _counselors = [];
  bool _loading = true;
  bool _hiring = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(nikahHireRepositoryProvider);
      final counselors = await repo.counselors();
      setState(() => _counselors = counselors);
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _hire(NikahCounselor counselor) async {
    setState(() => _hiring = true);
    try {
      final repo = ref.read(nikahHireRepositoryProvider);
      await repo.hire(counselor.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${counselor.name} has been notified and will take it from here.')));
        context.pushReplacement('/nikah/counselor/package');
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneric)));
    } finally {
      if (mounted) setState(() => _hiring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('nikah'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Choose a Nikah Counselor')),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _counselors.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)));
    }

    if (_counselors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('No counselors are available right now — please check back soon.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'A Nikah Counselor will personally search for matches, review proposals with you, and guide you through the process.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 16),
        for (final counselor in _counselors)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        backgroundImage: (counselor.avatar ?? '').isNotEmpty ? NetworkImage(counselor.avatar!) : null,
                        child: (counselor.avatar ?? '').isEmpty ? const Icon(Icons.person) : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(counselor.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            Text('${_tierBadges[counselor.tier] ?? '🥉'} ${(counselor.tier ?? 'nikah_counselor').replaceAll('_', ' ')}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if ((counselor.bio ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(counselor.bio!, style: const TextStyle(fontSize: 13)),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _hiring ? null : () => _hire(counselor),
                    child: Text('Choose ${counselor.name}'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
