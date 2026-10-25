import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/nikah_repository.dart';
import '../state/nikah_controller.dart';

class NikahBlockedScreen extends ConsumerStatefulWidget {
  const NikahBlockedScreen({super.key});

  @override
  ConsumerState<NikahBlockedScreen> createState() => _NikahBlockedScreenState();
}

class _NikahBlockedScreenState extends ConsumerState<NikahBlockedScreen> {
  List<NikahBlockedProfile> _blocked = [];
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
      final blocked = await repo.blockedList();
      setState(() => _blocked = blocked);
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(int blockId) async {
    try {
      final repo = ref.read(nikahRepositoryProvider);
      await repo.unblockProfile(blockId);
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
        appBar: AppBar(title: const Text('Blocked Profiles')),
        body: RefreshIndicator(onRefresh: _load, child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _blocked.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _blocked.isEmpty) {
      return ListView(
        children: [Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(_error!)))],
      );
    }

    if (_blocked.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Icon(Icons.block, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No blocked profiles.', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _blocked.length,
      itemBuilder: (context, index) {
        final b = _blocked[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(b.name ?? 'Profile #${b.profileId ?? ''}'),
            subtitle: Text([if (b.age != null) '${b.age} yrs', if (b.city != null) b.city!].join(' · ')),
            trailing: OutlinedButton(
              onPressed: () => _unblock(b.blockId),
              child: const Text('Unblock'),
            ),
          ),
        );
      },
    );
  }
}
