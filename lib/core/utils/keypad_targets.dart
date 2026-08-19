import '../../models/order_model.dart';

/// Finds the first order whose displayed number matches [typed].
///
/// Matching order:
/// 1. Exact string equality against [titleNumber].
/// 2. Numeric fallback via [int.tryParse] on both sides (`7` matches `007`).
/// 3. First match in [orders] order wins on duplicates.
///
/// [titleNumber] must be the same function the card header uses
/// (`orderTitleNumber(order, source)`). This helper does not read
/// `displayNumber` or `kotNumber` itself.
String? orderIdForTypedNumber({
  required List<Order> orders,
  required String typed,
  required String Function(Order order) titleNumber,
}) {
  if (typed.isEmpty) {
    return null;
  }

  for (final Order order in orders) {
    if (titleNumber(order) == typed) {
      return order.id;
    }
  }

  final int? typedNumber = int.tryParse(typed);
  if (typedNumber == null) {
    return null;
  }
  for (final Order order in orders) {
    final int? displayed = int.tryParse(titleNumber(order));
    if (displayed != null && displayed == typedNumber) {
      return order.id;
    }
  }
  return null;
}

/// The id [delta] steps from [currentId] in board reading order.
///
/// Returns null at either end, so `+`/`-` can flash and leave the ring where
/// it is rather than wrapping past the edge of the board. Also null when
/// [currentId] is absent from [orderedIds], which means the ring has nothing
/// to step from.
String? stepBoardOrderId({
  required List<String> orderedIds,
  required String? currentId,
  required int delta,
}) {
  if (currentId == null || delta == 0) {
    return null;
  }
  final int current = orderedIds.indexOf(currentId);
  if (current < 0) {
    return null;
  }
  final int next = current + delta;
  if (next < 0 || next >= orderedIds.length) {
    return null;
  }
  return orderedIds[next];
}

/// The ticket Enter picks on a calm board (nothing typed, nothing ringed).
///
/// Prefers the first not-yet-started ticket: a ticket that just arrived is
/// always unstarted, so this reaches an unnoticed order even when it packed
/// off-screen. Falls back to the first ticket in board order once everything
/// is started. Stale leftovers are skipped both ways because they can only be
/// cleared by touch.
String? entryBoardOrderId({
  required List<Order> ordered,
  required bool Function(String orderId) isStale,
}) {
  String? fallback;
  for (final Order order in ordered) {
    if (isStale(order.id)) {
      continue;
    }
    if (order.status == OrderStatus.newOrder) {
      return order.id;
    }
    fallback ??= order.id;
  }
  return fallback;
}

/// 1-based index from typed digits into a list of [length].
///
/// Returns a 0-based index, or null when [typed] is empty, not an integer,
/// less than 1, or greater than [length].
int? elementIndexForTypedDigits(String typed, int length) {
  final int? n = int.tryParse(typed);
  if (n == null || n < 1 || n > length) {
    return null;
  }
  return n - 1;
}
