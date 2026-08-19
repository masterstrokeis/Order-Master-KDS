import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/utils/keypad_targets.dart';
import 'package:order_master_kds/core/utils/order_title_number.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';

Order _order({
  required String id,
  required String displayNumber,
  String? kotNumber,
  OrderStatus status = OrderStatus.cooking,
}) {
  return Order(
    id: id,
    displayNumber: displayNumber,
    kotNumber: kotNumber,
    stationId: 'station-1',
    createdAt: DateTime.utc(2026, 8, 18, 12),
    type: OrderType.dineIn,
    status: status,
    items: const <OrderItem>[],
  );
}

void main() {
  group('orderIdForTypedNumber', () {
    test('exact string match', () {
      final List<Order> orders = <Order>[
        _order(id: 'a', displayNumber: '18'),
        _order(id: 'b', displayNumber: '19'),
      ];
      expect(
        orderIdForTypedNumber(
          orders: orders,
          typed: '18',
          titleNumber: (Order o) => o.displayNumber,
        ),
        'a',
      );
    });

    test('leading-zero exactness: typed 007 matches 007, not 7', () {
      final List<Order> orders = <Order>[
        _order(id: 'seven', displayNumber: '7'),
        _order(id: 'padded', displayNumber: '007'),
      ];
      expect(
        orderIdForTypedNumber(
          orders: orders,
          typed: '007',
          titleNumber: (Order o) => o.displayNumber,
        ),
        'padded',
      );
    });

    test('numeric fallback: typed 7 matches displayed 007', () {
      final List<Order> orders = <Order>[
        _order(id: 'padded', displayNumber: '007'),
      ];
      expect(
        orderIdForTypedNumber(
          orders: orders,
          typed: '7',
          titleNumber: (Order o) => o.displayNumber,
        ),
        'padded',
      );
    });

    test('duplicate displayed numbers: first in list wins', () {
      final List<Order> orders = <Order>[
        _order(id: 'first', displayNumber: '5'),
        _order(id: 'second', displayNumber: '5'),
      ];
      expect(
        orderIdForTypedNumber(
          orders: orders,
          typed: '5',
          titleNumber: (Order o) => o.displayNumber,
        ),
        'first',
      );
    });

    test('no match returns null', () {
      final List<Order> orders = <Order>[_order(id: 'a', displayNumber: '18')];
      expect(
        orderIdForTypedNumber(
          orders: orders,
          typed: '99',
          titleNumber: (Order o) => o.displayNumber,
        ),
        isNull,
      );
    });

    test('empty typed returns null', () {
      expect(
        orderIdForTypedNumber(
          orders: <Order>[_order(id: 'a', displayNumber: '1')],
          typed: '',
          titleNumber: (Order o) => o.displayNumber,
        ),
        isNull,
      );
    });

    test('uses injected titleNumber (KOT), not displayNumber directly', () {
      final List<Order> orders = <Order>[
        _order(id: 'a', displayNumber: '5', kotNumber: '12'),
      ];
      expect(
        orderIdForTypedNumber(
          orders: orders,
          typed: '12',
          titleNumber: (Order o) =>
              orderTitleNumber(o, OrderTitleNumberSource.kotNumber),
        ),
        'a',
      );
      expect(
        orderIdForTypedNumber(
          orders: orders,
          typed: '5',
          titleNumber: (Order o) =>
              orderTitleNumber(o, OrderTitleNumberSource.kotNumber),
        ),
        isNull,
      );
    });
  });

  group('stepBoardOrderId', () {
    const List<String> ids = <String>['a', 'b', 'c'];

    test('steps forward and backward one ticket at a time', () {
      expect(
        stepBoardOrderId(orderedIds: ids, currentId: 'a', delta: 1),
        'b',
      );
      expect(
        stepBoardOrderId(orderedIds: ids, currentId: 'c', delta: -1),
        'b',
      );
    });

    test('returns null at both ends instead of wrapping', () {
      expect(
        stepBoardOrderId(orderedIds: ids, currentId: 'c', delta: 1),
        isNull,
      );
      expect(
        stepBoardOrderId(orderedIds: ids, currentId: 'a', delta: -1),
        isNull,
      );
    });

    test('null or unknown current id returns null', () {
      expect(
        stepBoardOrderId(orderedIds: ids, currentId: null, delta: 1),
        isNull,
      );
      expect(
        stepBoardOrderId(orderedIds: ids, currentId: 'gone', delta: 1),
        isNull,
      );
    });

    test('single ticket board has nowhere to step', () {
      expect(
        stepBoardOrderId(
          orderedIds: const <String>['only'],
          currentId: 'only',
          delta: 1,
        ),
        isNull,
      );
    });
  });

  group('entryBoardOrderId', () {
    bool noneStale(String id) => false;

    test('prefers the first unstarted ticket over an earlier cooking one', () {
      expect(
        entryBoardOrderId(
          ordered: <Order>[
            _order(id: 'cooking', displayNumber: '1'),
            _order(
              id: 'fresh',
              displayNumber: '2',
              status: OrderStatus.newOrder,
            ),
          ],
          isStale: noneStale,
        ),
        'fresh',
      );
    });

    test('falls back to the first ticket once everything is started', () {
      expect(
        entryBoardOrderId(
          ordered: <Order>[
            _order(id: 'first', displayNumber: '1'),
            _order(id: 'second', displayNumber: '2'),
          ],
          isStale: noneStale,
        ),
        'first',
      );
    });

    test('skips stale leftovers, which only touch can clear', () {
      expect(
        entryBoardOrderId(
          ordered: <Order>[
            _order(
              id: 'stale',
              displayNumber: '1',
              status: OrderStatus.newOrder,
            ),
            _order(
              id: 'fresh',
              displayNumber: '2',
              status: OrderStatus.newOrder,
            ),
          ],
          isStale: (String id) => id == 'stale',
        ),
        'fresh',
      );
    });

    test('all stale or empty board returns null', () {
      expect(
        entryBoardOrderId(
          ordered: <Order>[_order(id: 'stale', displayNumber: '1')],
          isStale: (String id) => true,
        ),
        isNull,
      );
      expect(
        entryBoardOrderId(ordered: <Order>[], isStale: noneStale),
        isNull,
      );
    });
  });

  group('elementIndexForTypedDigits', () {
    test('1-based typed index to 0-based list index', () {
      expect(elementIndexForTypedDigits('1', 3), 0);
      expect(elementIndexForTypedDigits('3', 3), 2);
    });

    test('out of range returns null', () {
      expect(elementIndexForTypedDigits('4', 3), isNull);
      expect(elementIndexForTypedDigits('0', 3), isNull);
      expect(elementIndexForTypedDigits('-1', 3), isNull);
    });

    test('non-numeric and empty return null', () {
      expect(elementIndexForTypedDigits('ab', 3), isNull);
      expect(elementIndexForTypedDigits('', 3), isNull);
    });

    test('leading-zero typed index still parses', () {
      expect(elementIndexForTypedDigits('02', 3), 1);
    });
  });
}
