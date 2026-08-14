import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/urgency_settings.dart';

/// Persists [UrgencySettings] via SharedPreferences (same shape as theme prefs).
class UrgencySettingsService {
  UrgencySettingsService({this._preferences});

  static const String prefsKey = 'urgency_settings';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  /// Loads saved settings, or [UrgencySettings.defaults] when missing/corrupt.
  Future<UrgencySettings> load() async {
    final SharedPreferences prefs = await _prefs();
    final String? raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return UrgencySettings.defaults;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return UrgencySettings.defaults;
      }
      return UrgencySettings.fromJson(decoded);
    } on Object {
      return UrgencySettings.defaults;
    }
  }

  Future<void> save(UrgencySettings settings) async {
    final SharedPreferences prefs = await _prefs();
    await prefs.setString(prefsKey, jsonEncode(settings.toJson()));
  }
}
