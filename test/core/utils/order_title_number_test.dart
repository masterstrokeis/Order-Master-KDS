import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/utils/order_title_number.dart';
import 'package:order_master_kds/models/kds_order_event.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';

Order _order({required String displayNumber, String? kotNumber}) {
  return Order(
    id: 'ord_1',
    displayNumber: displayNumber,
    kotNumber: kotNumber,
    stationId: 'station_grill',
    createdAt: DateTime.utc(2026, 8, 14, 12),
    type: OrderType.dineIn,
    status: OrderStatus.cooking,
    items: const <OrderItem>[],
  );
}

KdsOrderEvent _event({required String displayNumber, String? kotNumber}) {
  return KdsOrderEvent(
    kind: KdsOrderEventKind.newOrder,
    orderId: 'ord_1',
    displayNumber: displayNumber,
    kotNumber: kotNumber,
    stationId: 'station_grill',
    type: OrderType.dineIn,
  );
}

void main() {
  test('display source always uses displayNumber', () {
    final Order order = _order(displayNumber: '5', kotNumber: '12');
    expect(
      orderTitleNumber(order, OrderTitleNumberSource.displayNumber),
      '5',
    );
  });

  test('kot source uses kotNumber when present', () {
    final Order order = _order(displayNumber: '5', kotNumber: '12');
    expect(orderTitleNumber(order, OrderTitleNumberSource.kotNumber), '12');
  });

  test('kot source falls back to displayNumber when kot is missing', () {
    expect(
      orderTitleNumber(
        _order(displayNumber: '5'),
        OrderTitleNumberSource.kotNumber,
      ),
      '5',
    );
    expect(
      orderTitleNumber(
        _order(displayNumber: '5', kotNumber: ''),
        OrderTitleNumberSource.kotNumber,
      ),
      '5',
    );
  });

  test('eventTitleNumber follows the same fallback', () {
    expect(
      eventTitleNumber(
        _event(displayNumber: '5', kotNumber: '12'),
        OrderTitleNumberSource.kotNumber,
      ),
      '12',
    );
    expect(
      eventTitleNumber(
        _event(displayNumber: '5'),
        OrderTitleNumberSource.kotNumber,
      ),
      '5',
    );
  });
}
