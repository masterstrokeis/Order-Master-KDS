import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class ThemePreferenceService {
  static const String _key = 'theme_mode';

  Future<ThemeMode> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    return switch (raw) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  Future<void> save(ThemeMode mode) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String value = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    };
    await prefs.setString(_key, value);
  }
}
