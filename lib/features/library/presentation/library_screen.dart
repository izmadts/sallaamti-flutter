import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/library_repository.dart';
import '../domain/library_item.dart';

final libraryCategoryFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

final libraryCategoriesProvider = FutureProvider.autoDispose((ref) => ref.watch(libraryRepositoryProvider).categories());

class LibraryListState {
  final List<LibraryItem> items;
  final int page;
  final int lastPage;
  final bool loading;
  final bool loadingMore;
  final Object? error;

  const LibraryListState({
    this.items = const [],
    this.page = 1,
    this.lastPage = 1,
    this.loading = true,
    this.loadingMore = false,
    this.error,
  });

  bool get hasMore => page < lastPage;

  LibraryListState copyWith({List<LibraryItem>? items, int? page, int? lastPage, bool? loading, bool? loadingMore, Object? error}) =>
      LibraryListState(
        items: items ?? this.items,
        page: page ?? this.page,
        lastPage: lastPage ?? this.lastPage,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error,
      );
}

// Same infinite-scroll pattern as the matchmaker app's ClientListController
// — a long-running library (more booklets added over time) shouldn't ever
// silently cap at the first page.
class LibraryListController extends StateNotifier<LibraryListState> {
  final LibraryRepository _repo;
  final String? _category;

  LibraryListController(this._repo, this._category) : super(const LibraryListState()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await _repo.index(category: _category, page: 1);
      state = LibraryListState(items: result.items, page: result.currentPage, lastPage: result.lastPage, loading: false);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e);
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> refresh() => _load();

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final nextPage = state.page + 1;
      final result = await _repo.index(category: _category, page: nextPage);
      state = state.copyWith(items: [...state.items, ...result.items], page: result.currentPage, lastPage: result.lastPage, loadingMore: false);
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }
}

final libraryListProvider = StateNotifierProvider.autoDispose<LibraryListController, LibraryListState>((ref) {
  final category = ref.watch(libraryCategoryFilterProvider);
  return LibraryListController(ref.watch(libraryRepositoryProvider), category);
});

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      ref.read(libraryListProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';
    final list = ref.watch(libraryListProvider);
    final categories = ref.watch(libraryCategoriesProvider);
    final selectedCategory = ref.watch(libraryCategoryFilterProvider);

    return Theme(
      data: ModuleThemes.forModule('library'),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.libraryTitle)),
        body: Column(
          children: [
            categories.when(
              data: (cats) => cats.isEmpty
                  ? const SizedBox.shrink()
                  : SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        children: [
                          _CategoryChip(label: l10n.categoryAllLabel, selected: selectedCategory == null, onTap: () => ref.read(libraryCategoryFilterProvider.notifier).state = null),
                          for (final cat in cats)
                            _CategoryChip(
                              label: '${cat.icon} ${isUrdu ? cat.labelUr : cat.labelEn}',
                              selected: selectedCategory == cat.key,
                              onTap: () => ref.read(libraryCategoryFilterProvider.notifier).state = cat.key,
                            ),
                        ],
                      ),
                    ),
              loading: () => const SizedBox(height: 48),
              error: (_, _) => const SizedBox(height: 48),
            ),
            Expanded(child: _buildBody(context, list)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, LibraryListState list) {
    final l10n = AppLocalizations.of(context)!;
    if (list.loading && list.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (list.error != null && list.items.isEmpty) {
      return RetryErrorView(
        message: list.error is ApiException ? (list.error as ApiException).displayMessage : l10n.errorGeneric,
        onRetry: () => ref.read(libraryListProvider.notifier).refresh(),
      );
    }

    if (list.items.isEmpty) {
      return EmptyStateView(emoji: '📚', title: l10n.libraryEmptyTitle, subtitle: l10n.libraryEmptySubtitle);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(libraryListProvider.notifier).refresh(),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.62),
        itemCount: list.items.length + (list.hasMore ? 2 : 0),
        itemBuilder: (context, index) {
          if (index >= list.items.length) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          return _LibraryCard(item: list.items[index]);
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final seed = ModuleThemes.seedFor('library');
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: seed,
        labelStyle: TextStyle(color: selected ? Colors.white : null, fontWeight: FontWeight.w600),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  final LibraryItem item;
  const _LibraryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final seed = ModuleThemes.seedFor('library');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/library/${item.slug}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: seed.withValues(alpha: 0.12)),
                  if (item.coverUrl != null)
                    Image.network(item.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _CoverFallback(title: item.title, seed: seed))
                  else
                    _CoverFallback(title: item.title, seed: seed),
                  if (item.isNew)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(999)),
                        child: Text(AppLocalizations.of(context)!.newBadge, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    [if (item.pages != null) AppLocalizations.of(context)!.pagesCountLabel(item.pages!), if (item.fileSizeHuman != null) item.fileSizeHuman!].join(' · '),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  final String title;
  final Color seed;
  const _CoverFallback({required this.title, required this.seed});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: seed,
      padding: const EdgeInsets.all(12),
      alignment: Alignment.center,
      child: Text(title, textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}
