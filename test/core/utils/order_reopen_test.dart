import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/utils/order_reopen.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';

final DateTime _t0 = DateTime.utc(2026, 8, 14, 10);

OrderItem _item({
  String id = 'item_1:station_grill',
  String name = 'Burger',
  int quantity = 1,
  bool isRemoved = false,
  bool isCompleted = false,
  bool isNew = false,
}) {
  return OrderItem(
    id: id,
    productId: 'prod_1',
    nameSnapshot: name,
    quantity: quantity,
    isRemoved: isRemoved,
    isCompleted: isCompleted,
    isNew: isNew,
  );
}

Order _order({
  OrderStatus status = OrderStatus.completed,
  int version = 1,
  DateTime? completedAt,
  List<OrderItem>? items,
}) {
  return Order(
    id: 'ord_1:station_grill',
    displayNumber: '1',
    stationId: 'station_grill',
    createdAt: _t0,
    updatedAt: _t0,
    completedAt: completedAt,
    type: OrderType.dineIn,
    status: status,
    version: version,
    tableNumber: '12',
    items: items ?? <OrderItem>[_item()],
  );
}

void main() {
  group('reopens a completed ticket', () {
    test('POS adds a new line', () {
      final Order previous = _order(items: <OrderItem>[_item()]);
      final Order next = _order(
        version: 2,
        items: <OrderItem>[
          _item(),
          _item(id: 'item_2:station_grill', name: 'Fries', isNew: true),
        ],
      );

      expect(
        shouldReopenCompletedOrder(previous: previous, next: next),
        isTrue,
      );
    });

    test('POS raises the quantity on an existing line', () {
      final Order previous = _order(items: <OrderItem>[_item(quantity: 1)]);
      final Order next = _order(
        version: 2,
        items: <OrderItem>[_item(quantity: 3)],
      );

      expect(
        shouldReopenCompletedOrder(previous: previous, next: next),
        isTrue,
      );
    });

    test('added line on a ticket whose items were all struck out', () {
      final Order previous = _order(
        items: <OrderItem>[_item(isCompleted: true)],
      );
      final Order next = _order(
        version: 2,
        items: <OrderItem>[
          _item(isCompleted: true),
          _item(id: 'item_2:station_grill', name: 'Fries'),
        ],
      );

      expect(
        shouldReopenCompletedOrder(previous: previous, next: next),
        isTrue,
      );
    });
  });

  group('leaves a completed ticket alone', () {
    test('quantity dropped', () {
      final Order previous = _order(items: <OrderItem>[_item(quantity: 3)]);
      final Order next = _order(
        version: 2,
        items: <OrderItem>[_item(quantity: 1)],
      );

      expect(
        shouldReopenCompletedOrder(previous: previous, next: next),
        isFalse,
      );
    });

    test('line removed', () {
      final Order previous = _order(
        items: <OrderItem>[
          _item(),
          _item(id: 'item_2:station_grill', name: 'Fries'),
        ],
      );
      final Order next = _order(
        version: 2,
        items: <OrderItem>[
          _item(),
          _item(id: 'item_2:station_grill', name: 'Fries', isRemoved: true),
        ],
      );

      expect(
        shouldReopenCompletedOrder(previous: previous, next: next),
        isFalse,
      );
    });

    test('only isCompleted toggled', () {
      final Order previous = _order(items: <OrderItem>[_item()]);
      final Order next = _order(
        version: 2,
        items: <OrderItem>[_item(isCompleted: true)],
      );

      expect(
        shouldReopenCompletedOrder(previous: previous, next: next),
        isFalse,
      );
    });

    test('identical snapshot', () {
      final Order previous = _order();
      final Order next = _order(version: 2);

      expect(
        shouldReopenCompletedOrder(previous: previous, next: next),
        isFalse,
      );
    });
  });

  group('only applies to completed tickets', () {
    test('cooking ticket gaining a line is already on the right tab', () {
      final Order previous = _order(
        status: OrderStatus.cooking,
        items: <OrderItem>[_item()],
      );
      final Order next = _order(
        status: OrderStatus.cooking,
        version: 2,
        items: <OrderItem>[
          _item(),
          _item(id: 'item_2:station_grill', name: 'Fries'),
        ],
      );

      expect(
        shouldReopenCompletedOrder(previous: previous, next: next),
        isFalse,
      );
    });

    test('POS snapshot already moved the ticket back to cooking', () {
      final Order previous = _order(items: <OrderItem>[_item()]);
      final Order next = _order(
        status: OrderStatus.cooking,
        version: 2,
        items: <OrderItem>[
          _item(),
          _item(id: 'item_2:station_grill', name: 'Fries'),
        ],
      );

      expect(
        shouldReopenCompletedOrder(previous: previous, next: next),
        isFalse,
      );
    });

    test('POS cancelled the ticket while adding a line', () {
      final Order previous = _order(items: <OrderItem>[_item()]);
      final Order next = _order(
        status: OrderStatus.cancelled,
        version: 2,
        items: <OrderItem>[
          _item(),
          _item(id: 'item_2:station_grill', name: 'Fries'),
        ],
      );

      expect(
        shouldReopenCompletedOrder(previous: previous, next: next),
        isFalse,
      );
    });
  });
}
