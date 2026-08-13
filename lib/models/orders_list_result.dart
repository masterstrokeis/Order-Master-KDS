import 'order_model.dart';

class OrdersListResult {
  const OrdersListResult({
    required this.serverTime,
    required this.stationId,
    required this.syncCursor,
    required this.orders,
  });

  factory OrdersListResult.fromJson(Map<String, dynamic> json) {
    return OrdersListResult(
      serverTime: DateTime.parse(json['serverTime'] as String),
      stationId: json['stationId'] as String,
      syncCursor: json['syncCursor'] as String?,
      orders: (json['orders'] as List<dynamic>)
          .map((dynamic e) => Order.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final DateTime serverTime;
  final String stationId;
  final String? syncCursor;
  final List<Order> orders;
}
