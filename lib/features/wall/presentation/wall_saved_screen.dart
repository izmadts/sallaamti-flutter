import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../data/wall_repository.dart';
import 'wall_item_card.dart';

class WallSavedScreen extends ConsumerStatefulWidget {
  const WallSavedScreen({super.key});

  @override
  ConsumerState<WallSavedScreen> createState() => _WallSavedScreenState();
}

class _WallSavedScreenState extends ConsumerState<WallSavedScreen> {
  final List<WallItem> _items = [];
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
      final result = await ref.read(wallRepositoryProvider).saved();
      setState(() {
        _items.clear();
        _items.addAll(result.items);
      });
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onItemChanged(WallItem updated) {
    if (!updated.isSaved) {
      setState(() => _items.removeWhere((i) => i.type == updated.type && i.id == updated.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('wall'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Saved')),
        body: SafeArea(
          child: RefreshIndicator(onRefresh: _load, child: _buildBody(context)),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return ListView(
        children: [
          Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(_error!, textAlign: TextAlign.center))),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(48),
            child: Center(
              child: Text('Nothing saved yet — tap the bookmark icon on anything you want to find again.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) => WallItemCard(
        key: ValueKey('${_items[index].type}-${_items[index].id}'),
        item: _items[index],
        onChanged: _onItemChanged,
      ),
    );
  }
}
