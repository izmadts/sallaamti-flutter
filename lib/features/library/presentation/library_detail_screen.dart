import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/library_download_manager.dart';
import '../data/library_repository.dart';
import '../domain/library_item.dart';

final libraryItemProvider = FutureProvider.autoDispose.family<LibraryItem, String>((ref, slug) => ref.watch(libraryRepositoryProvider).show(slug));

class LibraryDetailScreen extends ConsumerStatefulWidget {
  final String slug;
  const LibraryDetailScreen({super.key, required this.slug});

  @override
  ConsumerState<LibraryDetailScreen> createState() => _LibraryDetailScreenState();
}

class _LibraryDetailScreenState extends ConsumerState<LibraryDetailScreen> {
  bool _viewCounted = false;
  double? _downloadProgress;

  void _countViewOnce(LibraryItem item) {
    if (_viewCounted) return;
    _viewCounted = true;
    ref.read(libraryRepositoryProvider).event(item.slug, 'view').catchError((_) {});
  }

  Future<void> _download(LibraryItem item) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _downloadProgress = 0);
    try {
      await ref.read(libraryDownloadManagerProvider).download(
            item,
            onProgress: (received, total) {
              if (total > 0 && mounted) setState(() => _downloadProgress = received / total);
            },
          );
      ref.read(libraryRepositoryProvider).event(item.slug, 'download').catchError((_) {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.libraryDownloadCompleteMessage)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.libraryDownloadFailedMessage)));
    } finally {
      if (mounted) setState(() => _downloadProgress = null);
    }
  }

  Future<void> _deleteDownload(LibraryItem item) async {
    await ref.read(libraryDownloadManagerProvider).delete(item.slug);
    if (mounted) setState(() {});
  }

  // Link share (not the file) so the website gets the visit, same as the
  // web page's own WhatsApp-share button — the file-attachment option
  // below is the deliberate exception for when WhatsApp itself is the goal.
  Future<void> _shareLink(LibraryItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final url = item.shareUrl ?? 'https://sallaamti.com/library/${item.slug}';
    await SharePlus.instance.share(ShareParams(text: l10n.libraryShareTextMessage(item.title, url)));
    ref.read(libraryRepositoryProvider).event(item.slug, 'share').catchError((_) {});
  }

  Future<void> _sharePdfFile(LibraryItem item) async {
    final manager = ref.read(libraryDownloadManagerProvider);
    if (!await manager.isUpToDate(item)) {
      await _download(item);
    }
    final path = await manager.localPath(item.slug);
    await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: item.title));
    ref.read(libraryRepositoryProvider).event(item.slug, 'share').catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(libraryItemProvider(widget.slug));

    return Theme(
      data: ModuleThemes.forModule('library'),
      child: Scaffold(
        appBar: AppBar(title: const Text('')),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => RetryErrorView(
            message: e is ApiException ? e.displayMessage : l10n.errorGeneric,
            onRetry: () => ref.invalidate(libraryItemProvider(widget.slug)),
          ),
          data: (item) {
            _countViewOnce(item);
            return _buildBody(context, item);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, LibraryItem item) {
    final l10n = AppLocalizations.of(context)!;
    final seed = ModuleThemes.seedFor('library');

    return FutureBuilder<bool>(
      future: ref.read(libraryDownloadManagerProvider).isUpToDate(item),
      builder: (context, snapshot) {
        final isUpToDate = snapshot.data ?? false;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AspectRatio(
              aspectRatio: 0.75,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: item.coverUrl != null
                    ? Image.network(item.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _CoverFallback(title: item.title, seed: seed))
                    : _CoverFallback(title: item.title, seed: seed),
              ),
            ),
            const SizedBox(height: 20),
            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, height: 1.6)),
            const SizedBox(height: 10),
            if (item.description != null) ...[
              Text(item.description!, style: const TextStyle(height: 1.9)),
              const SizedBox(height: 10),
            ],
            Text(
              [if (item.pages != null) l10n.pagesCountLabel(item.pages!), 'PDF', if (item.fileSizeHuman != null) item.fileSizeHuman!, l10n.freeLabel].join(' · '),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            if (item.reviewNote != null) ...[
              const SizedBox(height: 6),
              Text('✅ ${item.reviewNote}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: seed, minimumSize: const Size.fromHeight(50)),
              icon: const Icon(Icons.menu_book),
              label: Text(l10n.libraryReadButton),
              onPressed: () => context.push('/library/${item.slug}/read', extra: item),
            ),
            const SizedBox(height: 10),
            if (_downloadProgress != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(value: _downloadProgress == 0 ? null : _downloadProgress),
              )
            else if (isUpToDate)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      label: Text(l10n.libraryDownloadedLabel),
                      onPressed: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: l10n.libraryDeleteDownloadTooltip,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteDownload(item),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), side: BorderSide(color: seed)),
                icon: const Icon(Icons.download_outlined),
                label: Text(l10n.libraryDownloadButton),
                onPressed: () => _download(item),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l10n.shareButton),
                    onPressed: () => _shareLink(item),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF25D366), side: const BorderSide(color: Color(0xFF25D366))),
                    icon: const Icon(Icons.chat_outlined),
                    label: Text(l10n.libraryPdfWhatsappButton),
                    onPressed: () => _sharePdfFile(item),
                  ),
                ),
              ],
            ),
          ],
        );
      },
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
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
    );
  }
}
