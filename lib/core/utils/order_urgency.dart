import '../../models/order_model.dart';
import 'order_elapsed.dart';

OrderUrgency urgencyForOrder(
  Order order,
  DateTime now, {
  required Duration warningThreshold,
  required Duration criticalThreshold,
}) {
  final Duration elapsed = elapsedSincePlaced(order, now);
  if (elapsed >= criticalThreshold) {
    return OrderUrgency.critical;
  }
  if (elapsed >= warningThreshold) {
    return OrderUrgency.warning;
  }
  return OrderUrgency.normal;
}
