import '../constants/kds_timing.dart';
import '../../models/order_model.dart';

OrderUrgency urgencyForOrder(Order order, DateTime now) {
  final Duration elapsed = now.difference(order.createdAt);
  if (elapsed >= KdsTiming.criticalThreshold) {
    return OrderUrgency.critical;
  }
  if (elapsed >= KdsTiming.warningThreshold) {
    return OrderUrgency.warning;
  }
  return OrderUrgency.normal;
}
