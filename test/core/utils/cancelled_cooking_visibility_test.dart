import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/utils/cancelled_cooking_visibility.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';

Order _order({
  required OrderStatus status,
  DateTime? cancelledAt,
  DateTime? updatedAt,
}) {
  final DateTime created = DateTime.utc(2026, 8, 14, 12);
  return Order(
    id: 'ord-1',
    displayNumber: '1',
    stationId: 'station-1',
    createdAt: created,
    updatedAt: updatedAt ?? created,
    cancelledAt: cancelledAt,
    type: OrderType.dineIn,
    status: status,
    items: const <OrderItem>[],
  );
}

void main() {
  final DateTime now = DateTime.utc(2026, 8, 14, 12, 0, 30);
  const Duration duration = Duration(seconds: 30);

  test('stampCancelledAt uses updatedAt on first cancel', () {
    final Order cooking = _order(status: OrderStatus.cooking);
    final DateTime cancelledAt = DateTime.utc(2026, 8, 14, 12, 0, 10);
    final Order incoming = cooking.copyWith(
      status: OrderStatus.cancelled,
      updatedAt: cancelledAt,
    );

    final Order stamped = stampCancelledAt(incoming, previous: cooking);

    expect(stamped.cancelledAt, cancelledAt);
  });

    test('stampCancelledAt keeps the first stamp after later patches', () {
    final DateTime first = DateTime.utc(2026, 8, 14, 12, 0, 10);
    final Order previous = _order(
      status: OrderStatus.cancelled,
      cancelledAt: first,
      updatedAt: first,
    );
    final Order fromNetwork = _order(
      status: OrderStatus.cancelled,
      updatedAt: first.add(const Duration(seconds: 20)),
    );

    final Order stamped = stampCancelledAt(fromNetwork, previous: previous);

    expect(stamped.cancelledAt, first);
  });

  test('cancelled stays on Cooking until duration elapses', () {
    final Order order = _order(
      status: OrderStatus.cancelled,
      cancelledAt: DateTime.utc(2026, 8, 14, 12, 0, 1),
    );

    expect(
      isCancelledVisibleOnCooking(
        order: order,
        now: now,
        duration: duration,
      ),
      isTrue,
    );
    expect(
      isVisibleOnCookingTab(
        order: order,
        now: now,
        cancelledDisplayDuration: duration,
      ),
      isTrue,
    );
  });

  test('cancelled leaves Cooking after duration', () {
    final Order order = _order(
      status: OrderStatus.cancelled,
      cancelledAt: DateTime.utc(2026, 8, 14, 11, 59, 59),
    );

    expect(
      isCancelledVisibleOnCooking(
        order: order,
        now: now,
        duration: duration,
      ),
      isFalse,
    );
    expect(
      isVisibleOnCookingTab(
        order: order,
        now: now,
        cancelledDisplayDuration: duration,
      ),
      isFalse,
    );
  });

  test('multiple cancelled orders expire independently', () {
    final Order recent = _order(
      status: OrderStatus.cancelled,
      cancelledAt: DateTime.utc(2026, 8, 14, 12, 0, 20),
    );
    final Order stale = _order(
      status: OrderStatus.cancelled,
      cancelledAt: DateTime.utc(2026, 8, 14, 11, 59, 0),
    );

    expect(
      isCancelledVisibleOnCooking(
        order: recent,
        now: now,
        duration: duration,
      ),
      isTrue,
    );
    expect(
      isCancelledVisibleOnCooking(
        order: stale,
        now: now,
        duration: duration,
      ),
      isFalse,
    );
  });

  test('configured duration of 15 seconds hides sooner', () {
    final Order order = _order(
      status: OrderStatus.cancelled,
      cancelledAt: DateTime.utc(2026, 8, 14, 12, 0, 10),
    );

    expect(
      isCancelledVisibleOnCooking(
        order: order,
        now: now,
        duration: const Duration(seconds: 15),
      ),
      isFalse,
    );
    expect(
      isCancelledVisibleOnCooking(
        order: order,
        now: now,
        duration: const Duration(seconds: 30),
      ),
      isTrue,
    );
  });
}
