import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../auth/state/auth_controller.dart';
import '../data/nikah_repository.dart';
import '../domain/nikah_profile.dart';

final nikahRepositoryProvider = Provider<NikahRepository>(
  (ref) => NikahRepository(ref.watch(apiClientProvider)),
);

enum NikahLoadStatus { loading, loaded }

class NikahState {
  final NikahLoadStatus status;
  final NikahProfile? profile;
  final String? error;
  const NikahState({required this.status, this.profile, this.error});
}

// Holds the member's own Nikah profile so the wizard steps, review screen,
// and dashboard tile all see the same up-to-date copy without each
// independently re-fetching — every wizard screen calls save() and reads
// the refreshed profile back from here afterward.
final nikahControllerProvider = StateNotifierProvider<NikahController, NikahState>(
  (ref) => NikahController(ref.watch(nikahRepositoryProvider)),
);

class NikahController extends StateNotifier<NikahState> {
  final NikahRepository _repository;

  NikahController(this._repository) : super(const NikahState(status: NikahLoadStatus.loading)) {
    refresh();
  }

  // A failed refresh() previously left `state` stuck at NikahLoadStatus
  // .loading forever — the screen just spun with no error and no way out.
  // Every path here now always lands on `loaded`, with `error` set when
  // it wasn't actually a success.
  Future<void> refresh() async {
    state = const NikahState(status: NikahLoadStatus.loading);
    try {
      final profile = await _repository.getMyProfile();
      state = NikahState(status: NikahLoadStatus.loaded, profile: profile);
    } on ApiException catch (e) {
      state = NikahState(status: NikahLoadStatus.loaded, error: e.message);
    } catch (_) {
      state = const NikahState(status: NikahLoadStatus.loaded, error: 'Something went wrong. Please try again.');
    }
  }

  // save()/submit() let their exceptions propagate — the wizard screens
  // that call these already catch ApiException themselves to show an
  // inline field/form error, which is more useful there than a generic
  // state.error would be.
  Future<void> save(Map<String, dynamic> fields, {Map<String, File> files = const {}}) async {
    final profile = await _repository.saveProfile(fields, files: files);
    state = NikahState(status: NikahLoadStatus.loaded, profile: profile);
  }

  Future<void> submit() => _repository.submitProfile();
}
