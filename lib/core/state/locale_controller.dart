import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_store.dart';

// null = not yet chosen (first launch) → the router sends the user to the
// language picker before anything else, per the "even a kid can explore"
// brief: language comes before any English-only screen, not after.
final localeControllerProvider = StateNotifierProvider<LocaleController, Locale?>(
  (ref) => LocaleController(ref),
);

// Separate from the Locale? state above: a saved locale is only known once
// the async storage read finishes, and "haven't checked yet" must be
// distinguishable from "checked, nothing saved" — otherwise a cold start
// always observes a transient null and sends even a returning user to the
// language picker before their saved choice loads (see SplashScreen).
final localeRestoredProvider = StateProvider<bool>((ref) => false);

class LocaleController extends StateNotifier<Locale?> {
  final Ref _ref;

  LocaleController(this._ref) : super(null) {
    _restore();
  }

  Future<void> _restore() async {
    final code = await SecureStore.readLocale();
    if (code != null) {
      state = Locale(code);
    }
    _ref.read(localeRestoredProvider.notifier).state = true;
  }

  Future<void> choose(String code) async {
    await SecureStore.saveLocale(code);
    state = Locale(code);
  }
}
