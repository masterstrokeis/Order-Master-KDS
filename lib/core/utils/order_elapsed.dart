import '../../models/order_model.dart';

Duration elapsedSince(DateTime placedAt, DateTime now) {
  return now.difference(placedAt);
}

Duration elapsedSincePlaced(Order order, DateTime now) {
  return elapsedSince(order.createdAt, now);
}

DateTime? terminalStampFor(Order order) {
  return switch (order.status) {
    OrderStatus.completed => order.completedAt ?? order.updatedAt,
    OrderStatus.cancelled => order.cancelledAt ?? order.updatedAt,
    OrderStatus.newOrder || OrderStatus.cooking => null,
  };
}

String formatElapsed(Duration elapsed) {
  final int minutes = elapsed.inMinutes;
  if (minutes < 0) {
    return '0m';
  }
  if (minutes < 60) {
    return '${minutes}m';
  }
  final int hours = minutes ~/ 60;
  final int remainingMinutes = minutes % 60;
  return '${hours}h ${remainingMinutes}m';
}
