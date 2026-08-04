import '../../models/order_model.dart';

/// Screen-scoped display data for one product occurrence on an active ticket.
class PrepLine {
  const PrepLine({
    required this.orderId,
    required this.displayNumber,
    required this.orderType,
    required this.serviceLabel,
    required this.quantity,
    required this.createdAt,
    required this.productName,
    this.customerName,
    this.modifierText,
    this.note,
  });

  final String orderId;
  final String displayNumber;
  final OrderType orderType;
  final String serviceLabel;
  final String? customerName;
  final int quantity;
  final String? modifierText;
  final String? note;
  final DateTime createdAt;
  final String productName;
}
