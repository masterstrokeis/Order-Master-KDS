import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/kds_timing.dart';

class OrderUpdatePulsePreferenceService {
  static const String prefsKey = 'order_update_pulse_seconds';
  static const int minSeconds = 5;
  static const int maxSeconds = 120;

  static int get defaultSeconds =>
      KdsTiming.orderUpdateHighlightDuration.inSeconds;

  Future<int> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? stored = prefs.getInt(prefsKey);
    if (stored == null) {
      return defaultSeconds;
    }
    return stored.clamp(minSeconds, maxSeconds);
  }

  Future<void> save(int seconds) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefsKey, seconds.clamp(minSeconds, maxSeconds));
  }
}
