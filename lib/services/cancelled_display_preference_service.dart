import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/kds_timing.dart';

class CancelledDisplayPreferenceService {
  static const String prefsKey = 'cancelled_cooking_display_seconds';

  static const List<int> optionsSeconds =
      KdsTiming.cancelledCookingDisplayOptionsSeconds;

  static int get defaultSeconds =>
      KdsTiming.cancelledCookingDisplayDuration.inSeconds;

  Future<int> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? stored = prefs.getInt(prefsKey);
    if (stored == null) {
      return defaultSeconds;
    }
    return _nearestOption(stored);
  }

  Future<void> save(int seconds) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefsKey, _nearestOption(seconds));
  }

  static int _nearestOption(int seconds) {
    int best = optionsSeconds.first;
    int bestDelta = (seconds - best).abs();
    for (final int option in optionsSeconds.skip(1)) {
      final int delta = (seconds - option).abs();
      if (delta < bestDelta) {
        best = option;
        bestDelta = delta;
      }
    }
    return best;
  }
}
