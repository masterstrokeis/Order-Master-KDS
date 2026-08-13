import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';

class SessionStore {
  SessionStore({SharedPreferences? preferences}) : _preferences = preferences;

  static const String prefsKey = 'kds_auth_session';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  Future<AuthSession?> load() async {
    final SharedPreferences prefs = await _prefs();
    final String? raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      await clear();
      return null;
    }
  }

  Future<void> save(AuthSession session) async {
    final SharedPreferences prefs = await _prefs();
    await prefs.setString(prefsKey, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await _prefs();
    await prefs.remove(prefsKey);
  }
}
