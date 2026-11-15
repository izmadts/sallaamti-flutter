import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/library_item.dart';

// Offline copies live in app-private storage (not the public Downloads
// folder — these are read inside the app's own PDF viewer, not meant to be
// browsed by other apps) under app_documents/library/<slug>.pdf. The
// version actually saved is tracked in SharedPreferences, separately from
// the file's own existence — a stale file plus a newer version number
// is exactly "re-download before opening", not "treat it as missing".
class LibraryDownloadManager {
  static const _prefsPrefix = 'library_downloaded_version_';

  Future<String> localPath(String slug) async {
    final dir = await getApplicationDocumentsDirectory();
    final libraryDir = Directory('${dir.path}/library');
    if (!await libraryDir.exists()) {
      await libraryDir.create(recursive: true);
    }
    return '${libraryDir.path}/$slug.pdf';
  }

  Future<int?> _savedVersion(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefsPrefix$slug');
  }

  Future<bool> isDownloaded(String slug) async {
    final path = await localPath(slug);
    return File(path).exists();
  }

  // Downloaded AND current — a file left over from before a PDF replace
  // (admin bumped version) must not look "ready to read offline" when it's
  // actually the old content.
  Future<bool> isUpToDate(LibraryItem item) async {
    if (!await isDownloaded(item.slug)) return false;
    final saved = await _savedVersion(item.slug);
    return saved != null && saved >= item.version;
  }

  Future<void> download(LibraryItem item, {void Function(int received, int total)? onProgress}) async {
    if (item.pdfUrl == null) throw StateError('This item has no PDF to download.');
    final path = await localPath(item.slug);
    await Dio().download(item.pdfUrl!, path, onReceiveProgress: onProgress);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefsPrefix${item.slug}', item.version);
  }

  Future<void> delete(String slug) async {
    final path = await localPath(slug);
    final file = File(path);
    if (await file.exists()) await file.delete();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefsPrefix$slug');
  }
}

final libraryDownloadManagerProvider = Provider((ref) => LibraryDownloadManager());
