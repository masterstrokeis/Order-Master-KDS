import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_config.dart';

class ServerConfigService {
  ServerConfigService({this._preferences});

  static const String prefsKey = 'kds_server_config';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  Future<ServerConfig?> load() async {
    final SharedPreferences prefs = await _prefs();
    final String? raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return ServerConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      await clear();
      return null;
    }
  }

  Future<void> save(ServerConfig config) async {
    final SharedPreferences prefs = await _prefs();
    await prefs.setString(prefsKey, jsonEncode(config.toJson()));
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await _prefs();
    await prefs.remove(prefsKey);
  }
}
