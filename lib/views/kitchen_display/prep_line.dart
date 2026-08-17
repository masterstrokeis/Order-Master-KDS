import '../../models/order_model.dart';

/// Screen-scoped display data for one product occurrence on an active ticket.
class PrepLine {
  const PrepLine({
    required this.orderId,
    required this.itemId,
    required this.displayNumber,
    required this.orderType,
    required this.serviceLabel,
    required this.quantity,
    required this.createdAt,
    required this.productName,
    required this.canComplete,
    required this.isCompleted,
    this.customerName,
    this.modifierText,
    this.note,
  });

  final String orderId;
  final String itemId;
  final String displayNumber;
  final OrderType orderType;
  final String serviceLabel;
  final String? customerName;
  final int quantity;
  final String? modifierText;
  final String? note;
  final DateTime createdAt;
  final String productName;
  final bool canComplete;
  final bool isCompleted;
}
