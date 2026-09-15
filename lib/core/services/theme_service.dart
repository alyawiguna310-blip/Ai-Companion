import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide theme mode holder.
///
/// Exposes [mode] as a [ValueNotifier] so `main.dart` can rebuild
/// MaterialApp whenever the user changes the theme. Persists the
/// choice via SharedPreferences.
class ThemeService {
  ThemeService._();

  static const String _storageKey = 'ai_companion_theme_mode';

  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Loads the persisted choice. Call once during app startup,
  /// before `runApp`.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      mode.value = _parse(raw);
    } catch (_) {
      mode.value = ThemeMode.system;
    }
  }

  /// Updates the mode and persists it.
  static Future<void> set(ThemeMode newMode) async {
    mode.value = newMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, newMode.name);
    } catch (_) {
      // Best-effort persistence — no UI impact if it fails.
    }
  }

  static ThemeMode _parse(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}