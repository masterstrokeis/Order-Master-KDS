import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/utils/announcement_burst.dart';
import 'package:order_master_kds/core/utils/order_announcement.dart';
import 'package:order_master_kds/models/kds_order_event.dart';
import 'package:order_master_kds/models/order_model.dart';

final DateTime _t0 = DateTime.utc(2026, 8, 14, 12);

KdsOrderEvent _event({
  required KdsOrderEventKind kind,
  String orderId = 'ord_1:station_grill',
  String displayNumber = '1',
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
    previousType: previousType,
    nextType: nextType,
  );
}

TimedAnnouncementEvent _timed(
  DateTime at, {
  KdsOrderEventKind kind = KdsOrderEventKind.newOrder,
  String orderId = 'ord_1:station_grill',
  String displayNumber = '1',
  OrderType type = OrderType.dineIn,
  OrderType? previousType,
  OrderType? nextType,
}) {
  return TimedAnnouncementEvent(
    event: _event(
      kind: kind,
      orderId: orderId,
      displayNumber: displayNumber,
      type: type,
      previousType: previousType,
      nextType: nextType,
    ),
    at: at,
  );
}

void main() {
  test('3 events within 2 seconds are not a burst', () {
    final DateTime now = _t0.add(const Duration(seconds: 2));
    expect(
      isBurst(
        timestamps: <DateTime>[
          _t0,
          _t0.add(const Duration(seconds: 1)),
          now,
        ],
        now: now,
      ),
      isFalse,
    );
  });

  test('4 events within 2 seconds are a burst', () {
    final DateTime now = _t0.add(const Duration(seconds: 2));
    expect(
      isBurst(
        timestamps: <DateTime>[
          _t0,
          _t0.add(const Duration(milliseconds: 500)),
          _t0.add(const Duration(seconds: 1)),
          now,
        ],
        now: now,
      ),
      isTrue,
    );
  });

  test('4 events spanning more than 2 seconds are not a burst', () {
    final DateTime now = _t0.add(const Duration(seconds: 3));
    expect(
      isBurst(
        timestamps: <DateTime>[
          _t0,
          _t0.add(const Duration(seconds: 1)),
          _t0.add(const Duration(seconds: 2)),
          now,
        ],
        now: now,
      ),
      isFalse,
    );
  });

  test('fourth unique order within 2s collapses to unique-order summary', () {
    List<TimedAnnouncementEvent> recent = <TimedAnnouncementEvent>[];
    List<String> pending = <String>[];
    AnnouncementBurstResult result = const AnnouncementBurstResult(
      pending: <String>[],
      recent: <TimedAnnouncementEvent>[],
      enqueued: <String>[],
    );

    for (int i = 0; i < 4; i++) {
      final DateTime at = _t0.add(Duration(milliseconds: i * 400));
      result = applyAnnouncementBurst(
        recent: recent,
        incoming: _timed(at, orderId: 'ord_$i:station_grill'),
        now: at,
        pending: pending,
      );
      recent = result.recent;
      pending = result.pending;
    }

    expect(result.enqueued, <String>[burstSummaryLine(4)]);
    expect(result.recent, isEmpty);
    expect(pending, <String>[burstSummaryLine(4)]);
  });

  test('four same-order updates in 2s speak one specific line, not overflow', () {
    List<TimedAnnouncementEvent> recent = <TimedAnnouncementEvent>[];
    List<String> pending = <String>[];
    AnnouncementBurstResult? last;

    for (int i = 0; i < 4; i++) {
      final DateTime at = _t0.add(Duration(milliseconds: i * 400));
      last = applyAnnouncementBurst(
        recent: recent,
        incoming: _timed(
          at,
          kind: KdsOrderEventKind.itemAdded,
          orderId: 'ord_125',
          displayNumber: '125',
        ),
        now: at,
        pending: pending,
      );
      recent = last.recent;
      pending = last.pending;
    }

    expect(last!.enqueued, isEmpty);
    expect(pending, <String>['Dine-in order 125, order updated.']);
    expect(pending, isNot(contains(announcementOverflowLine)));
    expect(pending, isNot(contains(burstSummaryLine(1))));
  });

  test('type-change after three announcements still speaks the type line', () {
    List<TimedAnnouncementEvent> recent = <TimedAnnouncementEvent>[];
    List<String> pending = <String>[];
    AnnouncementBurstResult? last;

    for (int i = 0; i < 3; i++) {
      final DateTime at = _t0.add(Duration(milliseconds: i * 200));
      last = applyAnnouncementBurst(
        recent: recent,
        incoming: _timed(
          at,
          kind: KdsOrderEventKind.itemAdded,
          orderId: 'ord_$i',
          displayNumber: '$i',
        ),
        now: at,
        pending: pending,
      );
      recent = last.recent;
      pending = last.pending;
    }

    final DateTime typeAt = _t0.add(const Duration(milliseconds: 800));
    last = applyAnnouncementBurst(
      recent: recent,
      incoming: _timed(
        typeAt,
        kind: KdsOrderEventKind.orderTypeChanged,
        orderId: 'ord_125',
        displayNumber: '125',
        type: OrderType.takeOut,
        previousType: OrderType.dineIn,
        nextType: OrderType.takeOut,
      ),
      now: typeAt,
      pending: pending,
    );

    expect(
      last.enqueued,
      <String>['Order 125 changed from Dine-in to Takeaway.'],
    );
    expect(last.enqueued, isNot(contains(announcementOverflowLine)));
  });

  test('cancelled still speaks when pending is already at overflow', () {
    final AnnouncementBurstResult result = applyAnnouncementBurst(
      recent: <TimedAnnouncementEvent>[
        _timed(_t0, kind: KdsOrderEventKind.itemAdded, orderId: 'ord_a'),
        _timed(
          _t0.add(const Duration(milliseconds: 200)),
          kind: KdsOrderEventKind.itemAdded,
          orderId: 'ord_b',
        ),
        _timed(
          _t0.add(const Duration(milliseconds: 400)),
          kind: KdsOrderEventKind.itemAdded,
          orderId: 'ord_c',
        ),
      ],
      incoming: _timed(
        _t0.add(const Duration(milliseconds: 600)),
        kind: KdsOrderEventKind.cancelled,
        orderId: 'ord_125',
        displayNumber: '125',
      ),
      now: _t0.add(const Duration(milliseconds: 600)),
      pending: <String>[
        'Dine-in order 0, order updated.',
        'Dine-in order 1, order updated.',
        announcementOverflowLine,
      ],
    );

    expect(result.enqueued, <String>['Dine-in order 125, order cancelled.']);
  });

  test('type-change revert after idle window speaks the new type line', () {
    AnnouncementBurstResult first = applyAnnouncementBurst(
      recent: const <TimedAnnouncementEvent>[],
      incoming: _timed(
        _t0,
        kind: KdsOrderEventKind.orderTypeChanged,
        orderId: 'ord_125',
        displayNumber: '125',
        type: OrderType.takeOut,
        previousType: OrderType.dineIn,
        nextType: OrderType.takeOut,
      ),
      now: _t0,
      pending: const <String>[],
    );

    expect(
      first.enqueued,
      <String>['Order 125 changed from Dine-in to Takeaway.'],
    );

    final DateTime later = _t0.add(const Duration(seconds: 3));
    final AnnouncementBurstResult revert = applyAnnouncementBurst(
      recent: first.recent,
      incoming: _timed(
        later,
        kind: KdsOrderEventKind.orderTypeChanged,
        orderId: 'ord_125',
        displayNumber: '125',
        type: OrderType.dineIn,
        previousType: OrderType.takeOut,
        nextType: OrderType.dineIn,
      ),
      now: later,
      pending: first.pending,
    );

    expect(
      revert.enqueued,
      <String>['Order 125 changed from Takeaway to Dine-in.'],
    );
  });

  test('enqueueWithCap keeps at most 3 and overflow-replaces the 4th', () {
    const String a = 'New order 1, table 3.';
    const String b = 'New order 2, table 3.';
    const String c = 'New order 3, table 3.';
    const String d = 'New order 4, table 3.';

    expect(enqueueWithCap(<String>[], a), <String>[a]);
    expect(enqueueWithCap(<String>[a], b), <String>[a, b]);
    expect(enqueueWithCap(<String>[a, b], c), <String>[a, b, c]);
    expect(
      enqueueWithCap(<String>[a, b, c], d),
      <String>[a, b, announcementOverflowLine],
    );
    expect(
      enqueueWithCap(<String>[a, b, announcementOverflowLine], d),
      <String>[a, b, announcementOverflowLine],
    );
  });

  test('idle window resets pending so an old cap cannot silence later speech', () {
    List<TimedAnnouncementEvent> recent = <TimedAnnouncementEvent>[];
    List<String> pending = <String>[];
    AnnouncementBurstResult? last;

    for (int i = 0; i < 3; i++) {
      final DateTime at = _t0.add(Duration(seconds: i * 3));
      last = applyAnnouncementBurst(
        recent: recent,
        incoming: _timed(at, orderId: 'ord_$i:station_grill'),
        now: at,
        pending: pending,
      );
      recent = last.recent;
      pending = last.pending;
    }

    final DateTime fourthAt = _t0.add(const Duration(seconds: 9));
    last = applyAnnouncementBurst(
      recent: recent,
      incoming: _timed(fourthAt, orderId: 'ord_3:station_grill'),
      now: fourthAt,
      pending: pending,
    );

    expect(last.enqueued, <String>['Dine-in order 1, new order.']);
    expect(last.enqueued, isNot(contains(announcementOverflowLine)));
  });
}
