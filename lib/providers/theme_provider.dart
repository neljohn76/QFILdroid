import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme.dart';

/// Holds the user's appearance preferences (brightness mode and accent
/// color) and persists them across launches.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({
    this.themeMode = ThemeMode.system,
    int accentIndex = 0,
  }) : _accentIndex = accentIndex;

  static const String _modeKey = 'theme.mode';
  static const String _accentKey = 'theme.accent';

  ThemeMode themeMode;
  int _accentIndex;

  int get accentIndex => _accentIndex;

  Color get seedColor =>
      QfildroidTheme.accents[_accentIndex.clamp(0, QfildroidTheme.accents.length - 1)]
          .color;

  /// Loads persisted preferences; falls back to system brightness and the
  /// QFIL green accent.
  static Future<ThemeProvider> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_modeKey) ?? ThemeMode.system.index;
    final accentIndex = prefs.getInt(_accentKey) ?? 0;
    return ThemeProvider(
      themeMode: ThemeMode
          .values[modeIndex.clamp(0, ThemeMode.values.length - 1)],
      accentIndex: accentIndex.clamp(0, QfildroidTheme.accents.length - 1),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (themeMode == mode) return;
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_modeKey, mode.index);
  }

  Future<void> setAccent(int index) async {
    final clamped = index.clamp(0, QfildroidTheme.accents.length - 1);
    if (_accentIndex == clamped) return;
    _accentIndex = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, _accentIndex);
  }
}
