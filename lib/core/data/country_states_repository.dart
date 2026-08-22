import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/state/auth_controller.dart';
import '../api/api_client.dart';

class CountryStates {
  final List<String> countries;
  final Map<String, List<String>> statesByCountry;
  const CountryStates({required this.countries, required this.statesByCountry});

  List<String> statesFor(String? country) => statesByCountry[country] ?? const [];
}

class CountryStatesRepository {
  final ApiClient _client;
  CountryStatesRepository(this._client);

  Future<CountryStates> fetch() async {
    final data = await _client.get('/meta/country-states');
    final states = (data['states'] as Map).map(
      (key, value) => MapEntry(key as String, (value as List).cast<String>()),
    );
    return CountryStates(
      countries: (data['countries'] as List).cast<String>(),
      statesByCountry: states,
    );
  }
}

final countryStatesRepositoryProvider = Provider<CountryStatesRepository>(
  (ref) => CountryStatesRepository(ref.watch(apiClientProvider)),
);

// Fetched once per app session and cached — this is static reference data
// (~250 countries / ~5,300 states, same dataset the website's Country/State
// dropdowns already use), not something that changes while the app is open.
final countryStatesProvider = FutureProvider<CountryStates>(
  (ref) => ref.watch(countryStatesRepositoryProvider).fetch(),
);
