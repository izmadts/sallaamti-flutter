import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_store.dart';

// null = not yet chosen (first launch) → the router sends the user to the
// language picker before anything else, per the "even a kid can explore"
// brief: language comes before any English-only screen, not after.
final localeControllerProvider = StateNotifierProvider<LocaleController, Locale?>(
  (ref) => LocaleController(),
);

class LocaleController extends StateNotifier<Locale?> {
  LocaleController() : super(null) {
    _restore();
  }

  Future<void> _restore() async {
    final code = await SecureStore.readLocale();
    if (code != null) {
      state = Locale(code);
    }
  }

  Future<void> choose(String code) async {
    await SecureStore.saveLocale(code);
    state = Locale(code);
  }
}
