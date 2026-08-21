import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/locale_controller.dart';

// A small always-visible toggle so language isn't a one-time choice locked
// in at first launch — tapping flips between English and Urdu immediately,
// anywhere this sits in an AppBar's actions.
class LanguageSwitchButton extends ConsumerWidget {
  const LanguageSwitchButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    final isUrdu = locale?.languageCode == 'ur';

    return TextButton(
      onPressed: () => ref.read(localeControllerProvider.notifier).choose(isUrdu ? 'en' : 'ur'),
      style: TextButton.styleFrom(foregroundColor: Colors.white),
      child: Text(
        isUrdu ? 'EN' : 'اردو',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    );
  }
}
