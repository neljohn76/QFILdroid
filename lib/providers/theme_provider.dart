import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme.dart';

/// Holds the user's appearance preferences (brightness mode and accent
/// color) and persists them across launches.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({
    this.themeMode = ThemeMode.system,
    int accentIndex = 0,
  }) : _accentIndex = _safeAccent(accentIndex);

  static const String _modeKey = 'theme.mode';
  static const String _accentKey = 'theme.accent';

  ThemeMode themeMode;
  int _accentIndex;

  int get accentIndex => _accentIndex;

  Color get seedColor => QfildroidTheme.accents[_accentIndex].color;

  static int _safeAccent(int index) {
    if (index < 0) return 0;
    if (index >= QfildroidTheme.accents.length) {
      return QfildroidTheme.accents.length - 1;
    }
    return index;
  }

  static ThemeMode _safeMode(int index) {
    if (index < 0 || index >= ThemeMode.values.length) {
      return ThemeMode.system;
    }
    return ThemeMode.values[index];
  }

  /// Loads persisted preferences; falls back to system brightness and the
  /// QFIL green accent.
  static Future<ThemeProvider> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_modeKey) ?? ThemeMode.system.index;
    final accentIndex = prefs.getInt(_accentKey) ?? 0;
    return ThemeProvider(
      themeMode: _safeMode(modeIndex),
      accentIndex: accentIndex,
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
    final clamped = _safeAccent(index);
    if (_accentIndex == clamped) return;
    _accentIndex = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, _accentIndex);
  }
}
