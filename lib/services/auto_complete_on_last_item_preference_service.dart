import 'package:shared_preferences/shared_preferences.dart';

class AutoCompleteOnLastItemPreferenceService {
  static const String prefsKey = 'auto_complete_on_last_item';

  Future<bool> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKey) ?? true;
  }

  Future<void> save(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, enabled);
  }
}
