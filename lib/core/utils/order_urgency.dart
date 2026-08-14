import '../../models/order_model.dart';

OrderUrgency urgencyForOrder(
  Order order,
  DateTime now, {
  required Duration warningThreshold,
  required Duration criticalThreshold,
}) {
  final Duration elapsed = now.difference(order.createdAt);
  if (elapsed >= criticalThreshold) {
    return OrderUrgency.critical;
  }
  if (elapsed >= warningThreshold) {
    return OrderUrgency.warning;
  }
  return OrderUrgency.normal;
}
