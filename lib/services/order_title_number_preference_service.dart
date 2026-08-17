import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/order_title_number.dart';

class OrderTitleNumberPreferenceService {
  static const String prefsKey = 'order_title_number_source';

  Future<OrderTitleNumberSource> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return parse(prefs.getString(prefsKey));
  }

  Future<void> save(OrderTitleNumberSource source) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, source.name);
  }

  static OrderTitleNumberSource parse(String? raw) {
    return switch (raw) {
      'kotNumber' => OrderTitleNumberSource.kotNumber,
      _ => OrderTitleNumberSource.displayNumber,
    };
  }
}
