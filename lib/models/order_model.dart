import 'order_item_model.dart';

enum OrderStatus { newOrder, cooking, completed }

enum OrderUrgency { normal, warning, critical }

enum OrderType { dineIn, delivery, takeOut }

class Order {
  const Order({
    required this.id,
    required this.displayNumber,
    required this.stationId,
    required this.createdAt,
    required this.type,
    required this.status,
    required this.items,
    this.tableNumber,
    this.customerName,
    this.note,
  });

  final String id;
  final String displayNumber;
  final String stationId;
  final DateTime createdAt;
  final OrderType type;
  final OrderStatus status;
  final List<OrderItem> items;
  final String? tableNumber;
  final String? customerName;
  final String? note;

  Order copyWith({
    String? id,
    String? displayNumber,
    String? stationId,
    DateTime? createdAt,
    OrderType? type,
    OrderStatus? status,
    List<OrderItem>? items,
    String? tableNumber,
    String? customerName,
    String? note,
  }) {
    return Order(
      id: id ?? this.id,
      displayNumber: displayNumber ?? this.displayNumber,
      stationId: stationId ?? this.stationId,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      status: status ?? this.status,
      items: items ?? this.items,
      tableNumber: tableNumber ?? this.tableNumber,
      customerName: customerName ?? this.customerName,
      note: note ?? this.note,
    );
  }
}
