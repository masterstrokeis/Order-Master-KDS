import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/utils/order_elapsed.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';

Order _order({
  required OrderStatus status,
  DateTime? completedAt,
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
    completedAt: completedAt,
    cancelledAt: cancelledAt,
    type: OrderType.dineIn,
    status: status,
    items: const <OrderItem>[],
  );
}

void main() {
  group('formatElapsed', () {
    test('minutes only under 60', () {
      expect(formatElapsed(Duration.zero), '0m');
      expect(formatElapsed(const Duration(minutes: 8)), '8m');
      expect(formatElapsed(const Duration(minutes: 59)), '59m');
    });

    test('hours and minutes at and above 60', () {
      expect(formatElapsed(const Duration(minutes: 60)), '1h 0m');
      expect(formatElapsed(const Duration(minutes: 61)), '1h 1m');
      expect(formatElapsed(const Duration(minutes: 72)), '1h 12m');
      expect(formatElapsed(const Duration(minutes: 125)), '2h 5m');
    });

    test('width worst case at 1439 minutes', () {
      expect(formatElapsed(const Duration(minutes: 1439)), '23h 59m');
    });

    test('uncapped past 24 hours', () {
      expect(formatElapsed(const Duration(minutes: 1440)), '24h 0m');
    });

    test('negative clamps to zero', () {
      expect(formatElapsed(const Duration(minutes: -5)), '0m');
    });
  });

  group('terminalStampFor', () {
    final DateTime created = DateTime.utc(2026, 8, 14, 12);
    final DateTime completedAt = DateTime.utc(2026, 8, 14, 12, 15);
    final DateTime updatedAt = DateTime.utc(2026, 8, 14, 12, 20);
    final DateTime cancelledAt = DateTime.utc(2026, 8, 14, 12, 10);

    test('completed uses completedAt', () {
      final Order order = _order(
        status: OrderStatus.completed,
        completedAt: completedAt,
        updatedAt: updatedAt,
      );

      expect(terminalStampFor(order), completedAt);
    });

    test('completed falls back to updatedAt when completedAt is null', () {
      final Order order = _order(
        status: OrderStatus.completed,
        updatedAt: updatedAt,
      );

      expect(terminalStampFor(order), updatedAt);
    });

    test('cancelled uses cancelledAt', () {
      final Order order = _order(
        status: OrderStatus.cancelled,
        cancelledAt: cancelledAt,
        updatedAt: updatedAt,
      );

      expect(terminalStampFor(order), cancelledAt);
    });

    test('cancelled falls back to updatedAt when cancelledAt is null', () {
      final Order order = _order(
        status: OrderStatus.cancelled,
        updatedAt: updatedAt,
      );

      expect(terminalStampFor(order), updatedAt);
    });

    test('cooking and newOrder return null', () {
      expect(terminalStampFor(_order(status: OrderStatus.cooking)), isNull);
      expect(terminalStampFor(_order(status: OrderStatus.newOrder)), isNull);
    });
  });

  group('elapsedSincePlaced', () {
    test('matches createdAt difference', () {
      final DateTime createdAt = DateTime.utc(2026, 8, 14, 12);
      final Order order = _order(status: OrderStatus.cooking).copyWith(
        createdAt: createdAt,
      );
      final DateTime now = createdAt.add(const Duration(minutes: 8));

      expect(
        elapsedSincePlaced(order, now),
        const Duration(minutes: 8),
      );
    });
  });
}
