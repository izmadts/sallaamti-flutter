import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/state/auth_controller.dart';
import '../api/api_client.dart';

// Unlike CountryStatesRepository (fetched once, ~5,300 states, cached for
// the whole session), the cities table has ~150k rows — too many to
// preload, so this is a live-search call per keystroke (debounced by the
// caller) rather than a cached provider.
class CitySearchRepository {
  final ApiClient _client;
  CitySearchRepository(this._client);

  Future<List<String>> search({
    required String query,
    String? country,
    String? state,
  }) async {
    final data = await _client.get(
      '/meta/cities',
      query: {
        'search': query,
        if (country != null) 'country': country,
        if (state != null) 'state': state,
      },
    );
    return (data['cities'] as List).cast<String>();
  }
}

final citySearchRepositoryProvider = Provider<CitySearchRepository>(
  (ref) => CitySearchRepository(ref.watch(apiClientProvider)),
);
