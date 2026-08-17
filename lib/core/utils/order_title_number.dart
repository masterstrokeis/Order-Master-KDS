import '../../models/kds_order_event.dart';
import '../../models/order_model.dart';

/// Which ticket number to show in titles and speak in announcements.
enum OrderTitleNumberSource { displayNumber, kotNumber }

String orderTitleNumber(Order order, OrderTitleNumberSource source) {
  return _preferKot(
    displayNumber: order.displayNumber,
    kotNumber: order.kotNumber,
    source: source,
  );
}

String eventTitleNumber(KdsOrderEvent event, OrderTitleNumberSource source) {
  return _preferKot(
    displayNumber: event.displayNumber,
    kotNumber: event.kotNumber,
    source: source,
  );
}

String _preferKot({
  required String displayNumber,
  required String? kotNumber,
  required OrderTitleNumberSource source,
}) {
  if (source == OrderTitleNumberSource.kotNumber) {
    final String? kot = kotNumber;
    if (kot != null && kot.isNotEmpty) {
      return kot;
    }
  }
  return displayNumber;
}
