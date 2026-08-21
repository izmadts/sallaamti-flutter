import 'package:flutter/material.dart';

// Every module gets its own seed color so switching between them visibly
// changes the app's mood — deliberate, per the brief that even a child
// should be able to tell modules apart at a glance. AppTheme.base is the
// brand shell (auth, dashboard, settings); ModuleThemes.forModule wraps a
// module's own screens once that module ships (Phase 1+).
class AppTheme {
  static const Color brandTeal = Color(0xFF0D6B6B);
  // Matches the app icon/splash artwork's own background — used on the
  // splash and welcome screens so the transparent corners of the logo
  // blend into the screen instead of showing a color seam.
  static const Color logoBackground = Color(0xFF022C22);

  static ThemeData get base => _themeFrom(brandTeal);

  static ThemeData _themeFrom(Color seed) {
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFFBFAF7),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        color: Colors.white,
      ),
    );
  }
}

class ModuleThemes {
  static const Map<String, Color> _seeds = {
    'nikah': Color(0xFFB8455A), // warm rose
    'quran': Color(0xFF0D6B6B), // brand teal
    'quran_live': Color(0xFF1D5FB8), // blue
    'skills': Color(0xFF6D4AAE), // purple
    'counseling': Color(0xFF2E8B8B), // calm blue-green
    'donation': Color(0xFFB8962E), // gold
    'volunteer': Color(0xFFD2691E), // orange
    'wall': Color(0xFF0D6B6B), // brand teal
  };

  static Color seedFor(String moduleKey) => _seeds[moduleKey] ?? AppTheme.brandTeal;

  static ThemeData forModule(String moduleKey) => AppTheme._themeFrom(seedFor(moduleKey));
}
