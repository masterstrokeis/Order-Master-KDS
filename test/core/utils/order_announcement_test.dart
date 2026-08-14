import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/utils/order_announcement.dart';
import 'package:order_master_kds/models/kds_order_event.dart';
import 'package:order_master_kds/models/order_model.dart';

KdsOrderEvent _event({
  required KdsOrderEventKind kind,
  String orderId = 'ord_2:station_grill',
  String displayNumber = '2',
  String? tableNumber = '3',
  String? itemName = 'Orange juice',
  int? oldQuantity,
  int? newQuantity,
  OrderType type = OrderType.dineIn,
  OrderType? previousType,
  OrderType? nextType,
}) {
  return KdsOrderEvent(
    kind: kind,
    orderId: orderId,
    displayNumber: displayNumber,
    stationId: 'station_grill',
    type: type,
    tableNumber: tableNumber,
    itemName: itemName,
    oldQuantity: oldQuantity,
    newQuantity: newQuantity,
    previousType: previousType,
    nextType: nextType,
  );
}

void main() {
  test('spokenOrderType maps dineIn, takeOut, and delivery', () {
    expect(spokenOrderType(OrderType.dineIn), 'Dine-in');
    expect(spokenOrderType(OrderType.takeOut), 'Takeaway');
    expect(spokenOrderType(OrderType.delivery), 'Delivery');
  });

  test('newOrder uses type and display number, without table', () {
    expect(
      announcementFor(_event(kind: KdsOrderEventKind.newOrder)),
      'Dine-in order 2, new order.',
    );
    expect(
      announcementFor(
        _event(kind: KdsOrderEventKind.newOrder, type: OrderType.takeOut),
      ),
      'Takeaway order 2, new order.',
    );
    expect(
      announcementFor(
        _event(kind: KdsOrderEventKind.newOrder, type: OrderType.delivery),
      ),
      'Delivery order 2, new order.',
    );
    expect(announcementFor(_event(kind: KdsOrderEventKind.newOrder)), isNot(contains('table')));
  });

  test('cancelled uses type and display number, without table', () {
    expect(
      announcementFor(_event(kind: KdsOrderEventKind.cancelled)),
      'Dine-in order 2, order cancelled.',
    );
    expect(
      announcementFor(
        _event(kind: KdsOrderEventKind.cancelled, type: OrderType.takeOut),
      ),
      'Takeaway order 2, order cancelled.',
    );
    expect(
      announcementFor(
        _event(kind: KdsOrderEventKind.cancelled, type: OrderType.delivery),
      ),
      'Delivery order 2, order cancelled.',
    );
  });

  test('item kinds and genericUpdate all speak order updated', () {
    const String expected = 'Dine-in order 2, order updated.';
    expect(announcementFor(_event(kind: KdsOrderEventKind.itemAdded)), expected);
    expect(
      announcementFor(_event(kind: KdsOrderEventKind.itemRemoved)),
      expected,
    );
    expect(
      announcementFor(
        _event(
          kind: KdsOrderEventKind.itemQuantityChanged,
          oldQuantity: 1,
          newQuantity: 3,
        ),
      ),
      expected,
    );
    expect(
      announcementFor(_event(kind: KdsOrderEventKind.genericUpdate)),
      expected,
    );
    expect(
      announcementFor(
        _event(kind: KdsOrderEventKind.itemAdded, type: OrderType.takeOut),
      ),
      'Takeaway order 2, order updated.',
    );
    expect(
      announcementFor(
        _event(kind: KdsOrderEventKind.genericUpdate, type: OrderType.delivery),
      ),
      'Delivery order 2, order updated.',
    );
  });

  test('orderTypeChanged uses spoken type names without table', () {
    expect(
      announcementFor(
        _event(
          kind: KdsOrderEventKind.orderTypeChanged,
          previousType: OrderType.dineIn,
          nextType: OrderType.takeOut,
          type: OrderType.takeOut,
        ),
      ),
      'Order 2 changed from Dine-in to Takeaway.',
    );
    expect(
      announcementFor(
        _event(
          kind: KdsOrderEventKind.orderTypeChanged,
          previousType: OrderType.takeOut,
          nextType: OrderType.dineIn,
          type: OrderType.dineIn,
        ),
      ),
      'Order 2 changed from Takeaway to Dine-in.',
    );
    expect(
      announcementFor(
        _event(
          kind: KdsOrderEventKind.orderTypeChanged,
          previousType: OrderType.dineIn,
          nextType: OrderType.delivery,
          type: OrderType.delivery,
        ),
      ),
      'Order 2 changed from Dine-in to Delivery.',
    );
  });

  test('coalesce collapses four item events on one order to one updated', () {
    final List<KdsOrderEvent> coalesced = coalesceAnnouncements(<KdsOrderEvent>[
      _event(kind: KdsOrderEventKind.itemAdded, itemName: 'A'),
      _event(kind: KdsOrderEventKind.itemAdded, itemName: 'B'),
      _event(kind: KdsOrderEventKind.itemRemoved, itemName: 'C'),
      _event(
        kind: KdsOrderEventKind.itemQuantityChanged,
        oldQuantity: 1,
        newQuantity: 2,
      ),
    ]);

    expect(coalesced, hasLength(1));
    expect(announcementFor(coalesced.single), 'Dine-in order 2, order updated.');
  });

  test('coalesce prefers type change over item edits', () {
    final List<KdsOrderEvent> coalesced = coalesceAnnouncements(<KdsOrderEvent>[
      _event(kind: KdsOrderEventKind.itemAdded),
      _event(
        kind: KdsOrderEventKind.orderTypeChanged,
        previousType: OrderType.dineIn,
        nextType: OrderType.takeOut,
        type: OrderType.takeOut,
      ),
      _event(kind: KdsOrderEventKind.itemRemoved),
    ]);

    expect(coalesced, hasLength(1));
    expect(
      announcementFor(coalesced.single),
      'Order 2 changed from Dine-in to Takeaway.',
    );
  });

  test('coalesce keeps one line per order when a batch has two orders', () {
    final List<KdsOrderEvent> coalesced = coalesceAnnouncements(<KdsOrderEvent>[
      _event(kind: KdsOrderEventKind.itemAdded, orderId: 'ord_a', displayNumber: '10'),
      _event(kind: KdsOrderEventKind.itemRemoved, orderId: 'ord_a', displayNumber: '10'),
      _event(kind: KdsOrderEventKind.itemAdded, orderId: 'ord_b', displayNumber: '11'),
    ]);

    expect(coalesced, hasLength(2));
    expect(announcementFor(coalesced[0]), 'Dine-in order 10, order updated.');
    expect(announcementFor(coalesced[1]), 'Dine-in order 11, order updated.');
  });

  test('coalesce leaves newOrder unchanged', () {
    final KdsOrderEvent created = _event(kind: KdsOrderEventKind.newOrder);
    expect(coalesceAnnouncements(<KdsOrderEvent>[created]), <KdsOrderEvent>[created]);
    expect(announcementFor(created), 'Dine-in order 2, new order.');
  });

  test('shouldPulseForEvent is false for new and cancelled', () {
    expect(shouldPulseForEvent(_event(kind: KdsOrderEventKind.newOrder)), isFalse);
    expect(shouldPulseForEvent(_event(kind: KdsOrderEventKind.cancelled)), isFalse);
    expect(shouldPulseForEvent(_event(kind: KdsOrderEventKind.itemAdded)), isTrue);
    expect(
      shouldPulseForEvent(_event(kind: KdsOrderEventKind.orderTypeChanged)),
      isTrue,
    );
  });
}
