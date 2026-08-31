import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../data/wall_repository.dart';
import 'wall_item_card.dart';
import 'wall_saved_screen.dart';
import 'wall_submit_dua_sheet.dart';

class WallScreen extends ConsumerStatefulWidget {
  const WallScreen({super.key});

  @override
  ConsumerState<WallScreen> createState() => _WallScreenState();
}

class _WallScreenState extends ConsumerState<WallScreen> {
  final List<WallItem> _items = [];
  final _scrollController = ScrollController();
  List<String> _availableTags = [];
  String _activeTag = 'all';
  int _page = 1;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 400) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _items.clear();
      }
    });

    try {
      final repo = ref.read(wallRepositoryProvider);
      final result = await repo.feed(tag: _activeTag == 'all' ? null : _activeTag, page: _page);
      setState(() {
        _items.addAll(result.items);
        _hasMore = result.hasMore;
        if (result.tags.isNotEmpty) _availableTags = result.tags;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    _page++;
    try {
      final repo = ref.read(wallRepositoryProvider);
      final result = await repo.feed(tag: _activeTag == 'all' ? null : _activeTag, page: _page);
      if (mounted) {
        setState(() {
          _items.addAll(result.items);
          _hasMore = result.hasMore;
        });
      }
    } catch (_) {
      _page--;
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _selectTag(String tag) {
    if (tag == _activeTag) return;
    setState(() => _activeTag = tag);
    _load(reset: true);
  }

  Future<void> _openSubmitDua() async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const WallSubmitDuaSheet(),
    );
    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your dua has been submitted and will appear once reviewed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('wall'),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sallaamti Wall'),
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmark_outline),
              tooltip: 'Saved',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WallSavedScreen())),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openSubmitDua,
          icon: const Text('🤲'),
          label: const Text('Share a Dua'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildTagBar(context),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: _buildBody(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagBar(BuildContext context) {
    final tags = ['all', 'dua', ..._availableTags];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: tags.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tag = tags[index];
          final selected = tag == _activeTag;
          final label = tag == 'all' ? 'All' : (tag == 'dua' ? '🤲 Duas' : tag);
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => _selectTag(tag),
            selectedColor: Theme.of(context).colorScheme.primary,
            labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
            backgroundColor: Colors.white,
            side: BorderSide(color: selected ? Colors.transparent : Colors.grey.shade300),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => _load(reset: true), child: const Text('Retry')),
              ],
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              children: [
                const Text('📣', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text('Nothing here yet.', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + 1,
      itemBuilder: (context, index) {
        if (index == _items.length) {
          if (!_hasMore) return const SizedBox(height: 24);
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return WallItemCard(
          key: ValueKey('${_items[index].type}-${_items[index].id}'),
          item: _items[index],
        );
      },
    );
  }
}
