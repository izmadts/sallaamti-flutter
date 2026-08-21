import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  const NikahState({required this.status, this.profile});
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

  Future<void> refresh() async {
    final profile = await _repository.getMyProfile();
    state = NikahState(status: NikahLoadStatus.loaded, profile: profile);
  }

  Future<void> save(Map<String, dynamic> fields, {Map<String, File> files = const {}}) async {
    final profile = await _repository.saveProfile(fields, files: files);
    state = NikahState(status: NikahLoadStatus.loaded, profile: profile);
  }

  Future<void> submit() => _repository.submitProfile();
}
