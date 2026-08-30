import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/nikah_avatar.dart';
import '../../../shared/widgets/trust_badges.dart';
import '../domain/nikah_card.dart';
import '../state/nikah_controller.dart';

class NikahSavedScreen extends ConsumerStatefulWidget {
  const NikahSavedScreen({super.key});

  @override
  ConsumerState<NikahSavedScreen> createState() => _NikahSavedScreenState();
}

class _NikahSavedScreenState extends ConsumerState<NikahSavedScreen> {
  List<NikahCard> _profiles = [];
  bool _loading = true;
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
      final repo = ref.read(nikahRepositoryProvider);
      final profiles = await repo.savedProfiles();
      setState(() => _profiles = profiles);
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unsave(int profileId) async {
    try {
      final repo = ref.read(nikahRepositoryProvider);
      await repo.toggleSave(profileId);
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneric)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('nikah'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Saved Profiles')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _profiles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _profiles.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Text('🔒', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      );
    }

    if (_profiles.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Icon(Icons.star_border, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'No saved profiles yet — tap the star on a profile in Browse to save it here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _profiles.length,
      itemBuilder: (context, index) {
        final card = _profiles[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => context.push('/nikah/profile/${card.id}'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NikahAvatar(photoUrl: card.photoUrl, radius: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${card.age} yrs · ${card.city}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        if ((card.profession ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(card.profession!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                        const SizedBox(height: 6),
                        TrustBadges(trustBadges: card.trustBadges, small: true),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.star, color: Colors.amber),
                    tooltip: 'Remove from saved',
                    onPressed: () => _unsave(card.id),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
