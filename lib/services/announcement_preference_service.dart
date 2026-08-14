import 'package:shared_preferences/shared_preferences.dart';

class AnnouncementPreferenceService {
  static const String prefsKey = 'announcements_enabled';

  Future<bool> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKey) ?? true;
  }

  Future<void> save(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, enabled);
  }
}
