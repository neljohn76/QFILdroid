import 'package:flutter/material.dart';

/// A named accent color used to seed the Material 3 color schemes.
class QfildroidAccent {
  const QfildroidAccent(this.name, this.color);

  final String name;
  final Color color;
}

/// Material 3 theme builder for QFILdroid.
///
/// Light and dark schemes are generated from the selected seed accent, so
/// the whole app follows the user's color theme. Semantic status colors
/// (success/warning/danger) stay fixed because they must remain
/// recognizable during flashing operations in both brightness modes.
class QfildroidTheme {
  const QfildroidTheme._();

  /// Default accent: QFIL green (#00BF63).
  static const Color defaultSeed = Color(0xFF00BF63);

  // Semantic status colors, readable on light and dark surfaces.
  static const Color success = Color(0xFF1F9D4D);
  static const Color warning = Color(0xFFC77700);
  static const Color danger = Color(0xFFE5484D);
  static const Color info = Color(0xFF3E9BD6);
  static const Color muted = Color(0xFF8B949E);

  /// Material 3 Expressive accent presets (default first).
  static const List<QfildroidAccent> accents = [
    QfildroidAccent('QFIL Green', Color(0xFF00BF63)),
    QfildroidAccent('Ocean Blue', Color(0xFF1E88E5)),
    QfildroidAccent('Violet', Color(0xFF7C4DFF)),
    QfildroidAccent('Sunset Orange', Color(0xFFE8710A)),
    QfildroidAccent('Crimson', Color(0xFFE0455E)),
    QfildroidAccent('Teal', Color(0xFF00BFA5)),
  ];

  static ThemeData light(Color seed) => _build(seed, Brightness.light);

  static ThemeData dark(Color seed) => _build(seed, Brightness.dark);

  static ThemeData _build(Color seed, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final outline = isDark ? const Color(0xFF2A313C) : const Color(0xFFD8DEE4);
    final surface = isDark ? const Color(0xFF161B22) : Colors.white;
    final surfaceHigh = isDark ? const Color(0xFF1F2630) : const Color(0xFFEFF3F1);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0E1116) : const Color(0xFFF6F8F7),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primary.withOpacity(0.22),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: outline),
        ),
      ),
      dividerColor: outline,
      listTileTheme: ListTileThemeData(iconColor: scheme.onSurfaceVariant),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: outline),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
