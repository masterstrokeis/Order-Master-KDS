import '../../models/order_model.dart';

/// Stamp [Order.cancelledAt] the first time an order is seen as cancelled.
/// Later patches keep the original stamp so [updatedAt] does not restart the
/// Cooking-tab window.
Order stampCancelledAt(Order order, {Order? previous}) {
  if (order.status != OrderStatus.cancelled) {
    return order;
  }
  final DateTime? kept =
      previous != null && previous.status == OrderStatus.cancelled
      ? previous.cancelledAt
      : null;
  return order.copyWith(
    cancelledAt: kept ?? order.cancelledAt ?? order.updatedAt,
  );
}

bool isCancelledVisibleOnCooking({
  required Order order,
  required DateTime now,
  required Duration duration,
}) {
  if (order.status != OrderStatus.cancelled) {
    return false;
  }
  final DateTime start = order.cancelledAt ?? order.updatedAt;
  return !now.isAfter(start.add(duration));
}

bool isVisibleOnCookingTab({
  required Order order,
  required DateTime now,
  required Duration cancelledDisplayDuration,
}) {
  return switch (order.status) {
    OrderStatus.newOrder || OrderStatus.cooking => true,
    OrderStatus.cancelled => isCancelledVisibleOnCooking(
      order: order,
      now: now,
      duration: cancelledDisplayDuration,
    ),
    OrderStatus.completed => false,
  };
}

bool hasCookingBoardOrders({
  required List<Order> orders,
  required String? stationId,
  required DateTime now,
  required Duration cancelledDisplayDuration,
}) {
  return orders.any((Order order) {
    if (stationId != null && order.stationId != stationId) {
      return false;
    }
    return isVisibleOnCookingTab(
      order: order,
      now: now,
      cancelledDisplayDuration: cancelledDisplayDuration,
    );
  });
}
