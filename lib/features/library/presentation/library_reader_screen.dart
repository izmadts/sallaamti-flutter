import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/module_themes.dart';
import '../data/library_download_manager.dart';
import '../domain/library_item.dart';

// Reads straight from the downloaded (or freshly-downloaded-just-now) local
// file — never streams page-by-page over the network — so page turns are
// instant and the book stays readable offline afterwards, matching the
// spec's "remembers the last page" requirement for a local PdfController.
class LibraryReaderScreen extends ConsumerStatefulWidget {
  final LibraryItem item;
  const LibraryReaderScreen({super.key, required this.item});

  @override
  ConsumerState<LibraryReaderScreen> createState() => _LibraryReaderScreenState();
}

class _LibraryReaderScreenState extends ConsumerState<LibraryReaderScreen> {
  static const _lastPagePrefix = 'library_last_page_';

  PdfController? _controller;
  int _currentPage = 1;
  int _pageCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final manager = ref.read(libraryDownloadManagerProvider);
      if (!await manager.isUpToDate(widget.item)) {
        await manager.download(widget.item);
      }
      final path = await manager.localPath(widget.item.slug);

      final prefs = await SharedPreferences.getInstance();
      final lastPage = prefs.getInt('$_lastPagePrefix${widget.item.slug}') ?? 1;

      final controller = PdfController(document: PdfDocument.openFile(path), initialPage: lastPage);
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _currentPage = lastPage;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'کتاب کھل نہیں سکی — دوبارہ کوشش کریں۔');
    }
  }

  Future<void> _rememberPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_lastPagePrefix${widget.item.slug}', page);
  }

  @override
  Widget build(BuildContext context) {
    final seed = ModuleThemes.seedFor('library');

    return Theme(
      data: ModuleThemes.forModule('library'),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          title: Text(widget.item.title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
          actions: [
            if (_pageCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Center(child: Text('$_currentPage / $_pageCount')),
              ),
          ],
        ),
        body: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                ),
              )
            : _controller == null
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : PdfView(
                    controller: _controller!,
                    scrollDirection: Axis.horizontal,
                    onDocumentLoaded: (document) => setState(() => _pageCount = document.pagesCount),
                    onPageChanged: (page) {
                      setState(() => _currentPage = page);
                      _rememberPage(page);
                    },
                  ),
      ),
    );
  }
}
