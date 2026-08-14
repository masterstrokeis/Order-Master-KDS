import 'order_item_model.dart';

enum OrderStatus { newOrder, cooking, completed, cancelled }

enum OrderUrgency { normal, warning, critical }

enum OrderType { dineIn, delivery, takeOut }

class Order {
  Order({
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
    this.version = 1,
    DateTime? updatedAt,
    this.completedAt,
    this.cancelledAt,
    String? sourceOrderId,
    this.kotNumber,
    this.restaurantId = 'rest_001',
    this.outletId = 'outlet_main',
  }) : updatedAt = updatedAt ?? createdAt,
       sourceOrderId = sourceOrderId ?? id;

  factory Order.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawItems =
        json['items'] as List<dynamic>? ?? const <dynamic>[];
    final List<OrderItem> items =
        rawItems
            .map(
              (dynamic e) => OrderItem.fromJson(e as Map<String, dynamic>),
            )
            .toList()
          ..sort((OrderItem a, OrderItem b) => a.sortOrder.compareTo(b.sortOrder));

    return Order(
      id: json['id'] as String,
      sourceOrderId: json['sourceOrderId'] as String? ?? json['id'] as String,
      displayNumber: json['displayNumber'] as String,
      kotNumber: json['kotNumber'] as String?,
      restaurantId: json['restaurantId'] as String? ?? 'rest_001',
      outletId: json['outletId'] as String? ?? 'outlet_main',
      stationId: json['stationId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(
        json['updatedAt'] as String? ?? json['createdAt'] as String,
      ),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      type: OrderType.values.byName(json['type'] as String),
      status: OrderStatus.values.byName(json['status'] as String),
      tableNumber: json['tableNumber'] as String?,
      customerName: json['customerName'] as String?,
      note: json['note'] as String?,
      version: json['version'] as int? ?? 1,
      items: items,
    );
  }

  final String id;
  final String sourceOrderId;
  final String displayNumber;
  final String? kotNumber;
  final String restaurantId;
  final String outletId;
  final String stationId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  /// Local first-seen cancel time. Not parsed from JSON.
  final DateTime? cancelledAt;
  final OrderType type;
  final OrderStatus status;
  final int version;
  final List<OrderItem> items;
  final String? tableNumber;
  final String? customerName;
  final String? note;

  Order copyWith({
    String? id,
    String? sourceOrderId,
    String? displayNumber,
    String? kotNumber,
    String? restaurantId,
    String? outletId,
    String? stationId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? cancelledAt,
    OrderType? type,
    OrderStatus? status,
    int? version,
    List<OrderItem>? items,
    String? tableNumber,
    String? customerName,
    String? note,
  }) {
    return Order(
      id: id ?? this.id,
      sourceOrderId: sourceOrderId ?? this.sourceOrderId,
      displayNumber: displayNumber ?? this.displayNumber,
      kotNumber: kotNumber ?? this.kotNumber,
      restaurantId: restaurantId ?? this.restaurantId,
      outletId: outletId ?? this.outletId,
      stationId: stationId ?? this.stationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      cancelledAt: cancelledAt ?? this.cancelledAt,
      type: type ?? this.type,
      status: status ?? this.status,
      version: version ?? this.version,
      items: items ?? this.items,
      tableNumber: tableNumber ?? this.tableNumber,
      customerName: customerName ?? this.customerName,
      note: note ?? this.note,
    );
  }
}
