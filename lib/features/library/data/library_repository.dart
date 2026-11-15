import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/state/auth_controller.dart';
import '../domain/library_item.dart';

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

// No auth required on the backend (GET /api/v1/library is outside the
// auth:sanctum group — these booklets are free to everyone), but ApiClient
// attaches the bearer token anyway when one exists; harmless either way.
class LibraryRepository {
  final ApiClient _client;
  LibraryRepository(this._client);

  Future<({List<LibraryItem> items, int currentPage, int lastPage})> index({String? category, int page = 1}) async {
    final data = await _client.get('/library', query: {
      if (category != null && category.isNotEmpty) 'category': category,
      'page': page,
    });
    return (
      items: (data['items'] as List).map((e) => LibraryItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      currentPage: _asInt(data['current_page']) ?? 1,
      lastPage: _asInt(data['last_page']) ?? 1,
    );
  }

  Future<List<LibraryCategory>> categories() async {
    final data = await _client.get('/library/categories');
    return (data['categories'] as List).map((e) => LibraryCategory.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<LibraryItem> show(String slug) async {
    final data = await _client.get('/library/$slug');
    return LibraryItem.fromJson(Map<String, dynamic>.from(data['item'] as Map));
  }

  // Fire-and-forget by design (view/download/share counters) — a failed
  // beat shouldn't interrupt reading, downloading or sharing, so callers
  // don't await this inline; see LibraryEventType's usages.
  Future<void> event(String slug, String type) async {
    await _client.post('/library/$slug/event', data: {'type': type});
  }
}

final libraryRepositoryProvider = Provider((ref) => LibraryRepository(ref.watch(apiClientProvider)));
