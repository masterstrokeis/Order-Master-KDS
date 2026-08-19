import '../../models/kds_order_event.dart';
import '../../models/order_model.dart';
import 'order_event_diff.dart';

/// True when [next] is a POS snapshot that adds chef-visible work to an order
/// the board has already completed, so the ticket must return to Cooking.
///
/// A quantity increase counts as new work. Removals, quantity decreases, and
/// `isCompleted` toggles do not reopen a finished ticket.
bool shouldReopenCompletedOrder({
  required Order previous,
  required Order next,
}) {
  if (previous.status != OrderStatus.completed) {
    return false;
  }
  // The POS already moved it off completed itself; nothing to roll back.
  if (next.status != OrderStatus.completed) {
    return false;
  }
  for (final KdsOrderEvent event in diffOrderEvents(previous, next)) {
    if (event.kind == KdsOrderEventKind.itemAdded) {
      return true;
    }
    if (event.kind == KdsOrderEventKind.itemQuantityChanged &&
        (event.newQuantity ?? 0) > (event.oldQuantity ?? 0)) {
      return true;
    }
  }
  return false;
}
