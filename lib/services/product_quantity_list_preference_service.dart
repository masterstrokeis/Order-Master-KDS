import 'package:shared_preferences/shared_preferences.dart';

class ProductQuantityListPreferenceService {
  static const String prefsKey = 'product_quantity_list_visible';

  Future<bool> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKey) ?? true;
  }

  Future<void> save(bool visible) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, visible);
  }
}
