import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/utils/order_event_diff.dart';
import 'package:order_master_kds/models/kds_order_event.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';

final DateTime _t0 = DateTime.utc(2026, 8, 14, 10);

OrderItem _item({
  String id = 'item_1:station_grill',
  String name = 'Burger',
  int quantity = 1,
  bool isRemoved = false,
  bool isRemovedUnseen = false,
  bool isCompleted = false,
  bool isNew = false,
  String? modifierText,
  String? note,
}) {
  return OrderItem(
    id: id,
    productId: 'prod_1',
    nameSnapshot: name,
    quantity: quantity,
    isRemoved: isRemoved,
    isRemovedUnseen: isRemovedUnseen,
    isCompleted: isCompleted,
    isNew: isNew,
    modifierText: modifierText,
    note: note,
  );
}

Order _order({
  OrderStatus status = OrderStatus.cooking,
  OrderType type = OrderType.dineIn,
  int version = 1,
  DateTime? updatedAt,
  DateTime? completedAt,
  String? tableNumber = '12',
  String? customerName,
  String? note,
  List<OrderItem>? items,
}) {
  return Order(
    id: 'ord_1:station_grill',
    displayNumber: '1',
    stationId: 'station_grill',
    createdAt: _t0,
    updatedAt: updatedAt ?? _t0,
    completedAt: completedAt,
    type: type,
    status: status,
    version: version,
    tableNumber: tableNumber,
    customerName: customerName,
    note: note,
    items: items ?? <OrderItem>[_item()],
  );
}

void main() {
  test('first insert with no previous is only newOrder', () {
    final Order next = _order(
      status: OrderStatus.newOrder,
      type: OrderType.takeOut,
      items: <OrderItem>[_item(), _item(id: 'item_2:station_grill', name: 'Fries')],
    );

    expect(
      diffOrderEvents(null, next),
      <KdsOrderEvent>[
        KdsOrderEvent(
          kind: KdsOrderEventKind.newOrder,
          orderId: next.id,
          displayNumber: next.displayNumber,
          stationId: next.stationId,
          type: next.type,
          tableNumber: next.tableNumber,
        ),
      ],
    );
  });

  test('cancelled status emits cancelled', () {
    final Order previous = _order();
    final Order next = _order(status: OrderStatus.cancelled, version: 2);

    expect(
      diffOrderEvents(previous, next).map((KdsOrderEvent e) => e.kind),
      <KdsOrderEventKind>[KdsOrderEventKind.cancelled],
    );
  });

  test('item added emits itemAdded', () {
    final Order previous = _order();
    final Order next = _order(
      version: 2,
      items: <OrderItem>[
        _item(),
        _item(id: 'item_2:station_grill', name: 'Fries', isNew: true),
      ],
    );

    final List<KdsOrderEvent> events = diffOrderEvents(previous, next);
    expect(events, <KdsOrderEvent>[
      KdsOrderEvent(
        kind: KdsOrderEventKind.itemAdded,
        orderId: next.id,
        displayNumber: next.displayNumber,
        stationId: next.stationId,
        type: next.type,
        tableNumber: next.tableNumber,
        itemId: 'item_2:station_grill',
        itemName: 'Fries',
      ),
    ]);
  });

  test('item removed via isRemoved flag emits itemRemoved', () {
    final Order previous = _order();
    final Order next = _order(
      version: 2,
      items: <OrderItem>[_item(isRemoved: true, isRemovedUnseen: true)],
    );

    expect(diffOrderEvents(previous, next), <KdsOrderEvent>[
      KdsOrderEvent(
        kind: KdsOrderEventKind.itemRemoved,
        orderId: next.id,
        displayNumber: next.displayNumber,
        stationId: next.stationId,
        type: next.type,
        tableNumber: next.tableNumber,
        itemId: 'item_1:station_grill',
        itemName: 'Burger',
      ),
    ]);
  });

  test('item removed via missing id emits itemRemoved', () {
    final Order previous = _order(
      items: <OrderItem>[
        _item(),
        _item(id: 'item_2:station_grill', name: 'Fries'),
      ],
    );
    final Order next = _order(version: 2, items: <OrderItem>[_item()]);

    expect(diffOrderEvents(previous, next), <KdsOrderEvent>[
      KdsOrderEvent(
        kind: KdsOrderEventKind.itemRemoved,
        orderId: next.id,
        displayNumber: next.displayNumber,
        stationId: next.stationId,
        type: next.type,
        tableNumber: next.tableNumber,
        itemId: 'item_2:station_grill',
        itemName: 'Fries',
      ),
    ]);
  });

  test('item quantity changed emits itemQuantityChanged', () {
    final Order previous = _order();
    final Order next = _order(version: 2, items: <OrderItem>[_item(quantity: 3)]);

    expect(diffOrderEvents(previous, next), <KdsOrderEvent>[
      KdsOrderEvent(
        kind: KdsOrderEventKind.itemQuantityChanged,
        orderId: next.id,
        displayNumber: next.displayNumber,
        stationId: next.stationId,
        type: next.type,
        tableNumber: next.tableNumber,
        itemId: 'item_1:station_grill',
        itemName: 'Burger',
        oldQuantity: 1,
        newQuantity: 3,
      ),
    ]);
  });

  test('removed wins over quantity on the same item', () {
    final Order previous = _order(items: <OrderItem>[_item(quantity: 2)]);
    final Order next = _order(
      version: 2,
      items: <OrderItem>[_item(quantity: 1, isRemoved: true)],
    );

    expect(
      diffOrderEvents(previous, next).map((KdsOrderEvent e) => e.kind),
      <KdsOrderEventKind>[KdsOrderEventKind.itemRemoved],
    );
  });

  test('order type changed emits orderTypeChanged', () {
    final Order previous = _order(type: OrderType.dineIn);
    final Order next = _order(type: OrderType.takeOut, version: 2);

    expect(diffOrderEvents(previous, next), <KdsOrderEvent>[
      KdsOrderEvent(
        kind: KdsOrderEventKind.orderTypeChanged,
        orderId: next.id,
        displayNumber: next.displayNumber,
        stationId: next.stationId,
        type: next.type,
        tableNumber: next.tableNumber,
        previousType: OrderType.dineIn,
        nextType: OrderType.takeOut,
      ),
    ]);
  });

  test('other-device start (newOrder to cooking) emits genericUpdate', () {
    final Order previous = _order(status: OrderStatus.newOrder);
    final Order next = _order(status: OrderStatus.cooking, version: 2);

    expect(
      diffOrderEvents(previous, next).map((KdsOrderEvent e) => e.kind),
      <KdsOrderEventKind>[KdsOrderEventKind.genericUpdate],
    );
  });

  test('item completed toggle emits genericUpdate', () {
    final Order previous = _order();
    final Order next = _order(
      version: 2,
      items: <OrderItem>[_item(isCompleted: true)],
    );

    expect(
      diffOrderEvents(previous, next).map((KdsOrderEvent e) => e.kind),
      <KdsOrderEventKind>[KdsOrderEventKind.genericUpdate],
    );
  });

  test('acknowledge isRemovedUnseen produces zero events', () {
    final Order previous = _order(
      items: <OrderItem>[_item(isRemoved: true, isRemovedUnseen: true)],
    );
    final Order next = _order(
      version: 2,
      items: <OrderItem>[_item(isRemoved: true, isRemovedUnseen: false)],
    );

    expect(diffOrderEvents(previous, next), isEmpty);
  });

  test('metadata-only version/updatedAt change produces zero events', () {
    final Order previous = _order(version: 2, updatedAt: _t0);
    final Order next = _order(
      version: 3,
      updatedAt: _t0.add(const Duration(seconds: 2)),
    );

    expect(diffOrderEvents(previous, next), isEmpty);
  });

  test(
    'optimistic self-action followed by matching server echo produces zero events',
    () {
      final DateTime t1 = _t0.add(const Duration(seconds: 1));
      final DateTime t2 = _t0.add(const Duration(seconds: 2));
      final Order previous = _order(
        status: OrderStatus.cooking,
        version: 2,
        updatedAt: t1,
      );
      final Order next = _order(
        status: OrderStatus.cooking,
        version: 5,
        updatedAt: t2,
      );

      expect(diffOrderEvents(previous, next), isEmpty);

      final DateTime completedAt1 = t1;
      final DateTime completedAt2 = t2;
      final Order previousComplete = _order(
        status: OrderStatus.completed,
        version: 3,
        updatedAt: t1,
        completedAt: completedAt1,
      );
      final Order nextComplete = _order(
        status: OrderStatus.completed,
        version: 8,
        updatedAt: t2,
        completedAt: completedAt2,
      );

      expect(diffOrderEvents(previousComplete, nextComplete), isEmpty);
    },
  );

  test('multi-event snapshot emits item add, qty change, and type change', () {
    final Order previous = _order(
      type: OrderType.dineIn,
      items: <OrderItem>[_item(quantity: 1)],
    );
    final Order next = _order(
      type: OrderType.delivery,
      version: 4,
      items: <OrderItem>[
        _item(quantity: 2),
        _item(id: 'item_2:station_grill', name: 'Salad'),
      ],
    );

    expect(
      diffOrderEvents(previous, next).map((KdsOrderEvent e) => e.kind).toList(),
      <KdsOrderEventKind>[
        KdsOrderEventKind.orderTypeChanged,
        KdsOrderEventKind.itemQuantityChanged,
        KdsOrderEventKind.itemAdded,
      ],
    );
  });

  test('cancelled snapshot can also include item events and skips generic', () {
    final Order previous = _order(
      items: <OrderItem>[_item(), _item(id: 'item_2:station_grill', name: 'Fries')],
    );
    final Order next = _order(
      status: OrderStatus.cancelled,
      version: 2,
      items: <OrderItem>[_item()],
    );

    expect(
      diffOrderEvents(previous, next).map((KdsOrderEvent e) => e.kind).toList(),
      <KdsOrderEventKind>[
        KdsOrderEventKind.cancelled,
        KdsOrderEventKind.itemRemoved,
      ],
    );
  });
}
