import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/authed_avatar.dart';
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
  Map<String, String> _filters = {};

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
      final counselors = await repo.counselors(city: _filters['city'], gender: _filters['gender']);
      setState(() => _counselors = counselors);
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CounselorFilterSheet(initial: _filters),
    );
    if (result != null) {
      setState(() => _filters = result);
      _load();
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
        appBar: AppBar(
          title: const Text('Choose a Nikah Counselor'),
          actions: [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(icon: const Icon(Icons.tune), tooltip: 'Filter', onPressed: _openFilters),
                if (_filters.isNotEmpty)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Color(0xFFB8962E), shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ],
        ),
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
          child: Text(
            _filters.isNotEmpty
                ? 'No counselors match that filter — try widening your search.'
                : 'No counselors are available right now — please check back soon.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
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
                      AuthedAvatar(
                        url: counselor.avatar,
                        radius: 28,
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        fallback: const Icon(Icons.person),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(counselor.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            Text('${_tierBadges[counselor.tier] ?? '🥉'} ${(counselor.tier ?? 'nikah_counselor').replaceAll('_', ' ')}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            if ((counselor.city ?? '').isNotEmpty || (counselor.gender ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if ((counselor.city ?? '').isNotEmpty) '📍 ${counselor.city}',
                                  if (counselor.gender == 'female') '♀ Female' else if (counselor.gender == 'male') '♂ Male',
                                ].join('   '),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
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

class _CounselorFilterSheet extends StatefulWidget {
  final Map<String, String> initial;
  const _CounselorFilterSheet({required this.initial});

  @override
  State<_CounselorFilterSheet> createState() => _CounselorFilterSheetState();
}

class _CounselorFilterSheetState extends State<_CounselorFilterSheet> {
  late final _cityController = TextEditingController(text: widget.initial['city']);
  String? _gender;

  @override
  void initState() {
    super.initState();
    _gender = widget.initial['gender'];
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  void _apply() {
    final filters = <String, String>{
      if (_cityController.text.trim().isNotEmpty) 'city': _cityController.text.trim(),
      if (_gender != null) 'gender': _gender!,
    };
    Navigator.of(context).pop(filters);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Filter Counselors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cityController,
            decoration: const InputDecoration(labelText: 'City'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Any')),
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
            ],
            onChanged: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(<String, String>{}),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(onPressed: _apply, child: const Text('Apply')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
