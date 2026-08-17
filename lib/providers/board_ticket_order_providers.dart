import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/utils/board_ticket_order.dart';
import '../services/board_ticket_order_preference_service.dart';

final Provider<BoardTicketOrderPreferenceService>
boardTicketOrderPreferenceServiceProvider =
    Provider<BoardTicketOrderPreferenceService>(
      (Ref ref) => BoardTicketOrderPreferenceService(),
    );

/// Oldest-first is the kitchen default (oldest work top-left).
final StateProvider<BoardTicketOrder> boardTicketOrderProvider =
    StateProvider<BoardTicketOrder>(
      (Ref ref) => BoardTicketOrder.oldestFirst,
    );
