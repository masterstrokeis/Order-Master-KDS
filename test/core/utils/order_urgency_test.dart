import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/utils/order_urgency.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';

Order _order({required DateTime createdAt}) {
  return Order(
    id: 'ord_1:station_grill',
    displayNumber: '1',
    stationId: 'station_grill',
    createdAt: createdAt,
    type: OrderType.dineIn,
    status: OrderStatus.cooking,
    items: <OrderItem>[
      OrderItem(
        id: 'item_1:station_grill',
        productId: 'prod_1',
        nameSnapshot: 'Burger',
        quantity: 1,
      ),
    ],
  );
}

void main() {
  final DateTime createdAt = DateTime(2026, 8, 13, 12, 0);

  test('returns normal before warning threshold', () {
    final Order order = _order(createdAt: createdAt);
    final DateTime now = createdAt.add(const Duration(seconds: 59));

    expect(
      urgencyForOrder(
        order,
        now,
        warningThreshold: const Duration(minutes: 1),
        criticalThreshold: const Duration(minutes: 2),
      ),
      OrderUrgency.normal,
    );
  });

  test('returns warning at and above warning threshold', () {
    final Order order = _order(createdAt: createdAt);
    final DateTime now = createdAt.add(const Duration(minutes: 1));

    expect(
      urgencyForOrder(
        order,
        now,
        warningThreshold: const Duration(minutes: 1),
        criticalThreshold: const Duration(minutes: 2),
      ),
      OrderUrgency.warning,
    );
  });

  test('returns critical at and above critical threshold', () {
    final Order order = _order(createdAt: createdAt);
    final DateTime now = createdAt.add(const Duration(minutes: 2));

    expect(
      urgencyForOrder(
        order,
        now,
        warningThreshold: const Duration(minutes: 1),
        criticalThreshold: const Duration(minutes: 2),
      ),
      OrderUrgency.critical,
    );
  });

  test('uses injected thresholds rather than hardcoded defaults', () {
    final Order order = _order(createdAt: createdAt);
    final DateTime now = createdAt.add(const Duration(minutes: 5));

    expect(
      urgencyForOrder(
        order,
        now,
        warningThreshold: const Duration(minutes: 10),
        criticalThreshold: const Duration(minutes: 15),
      ),
      OrderUrgency.normal,
    );
    expect(
      urgencyForOrder(
        order,
        now,
        warningThreshold: const Duration(minutes: 3),
        criticalThreshold: const Duration(minutes: 8),
      ),
      OrderUrgency.warning,
    );
  });
}
