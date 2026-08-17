import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/board_ticket_order.dart';

class BoardTicketOrderPreferenceService {
  static const String prefsKey = 'board_ticket_order';

  Future<BoardTicketOrder> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return parse(prefs.getString(prefsKey));
  }

  Future<void> save(BoardTicketOrder order) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, order.name);
  }

  static BoardTicketOrder parse(String? raw) {
    return switch (raw) {
      'newestFirst' => BoardTicketOrder.newestFirst,
      _ => BoardTicketOrder.oldestFirst,
    };
  }
}
