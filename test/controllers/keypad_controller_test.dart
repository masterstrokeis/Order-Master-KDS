import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/keypad_controller.dart';
import 'package:order_master_kds/controllers/order_controller.dart';
import 'package:order_master_kds/core/constants/kds_timing.dart';
import 'package:order_master_kds/core/utils/board_ticket_order.dart';
import 'package:order_master_kds/core/utils/keypad_key_map.dart';
import 'package:order_master_kds/core/utils/order_title_number.dart';
import 'package:order_master_kds/models/complete_items_result.dart';
import 'package:order_master_kds/models/item_quantity.dart';
import 'package:order_master_kds/models/keypad_state.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/views/kitchen_display/prep_line.dart';

final DateTime _t0 = DateTime.utc(2026, 8, 18, 12);

const ItemGroupKey _burgerKey = ItemGroupKey(name: 'Burger', modifierText: '');

void main() {
  group('order-number type-ahead', () {
    test('valid match focuses the order', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
      );
      _type(h.keypad, '18', _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.state.focusedOrderId, 'c1');
      expect(h.state.digits, isEmpty);
      expect(h.state.flash, isNull);
    });

    test('no match flashes and clears the buffer', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
      );
      _type(h.keypad, '99', _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.state.focusedOrderId, isNull);
      expect(h.state.digits, isEmpty);
      expect(h.state.flash, 'No order #99');
    });

    test('search is scoped to the active tab only', () async {
      final _Harness h = await _harness(
        orders: <Order>[
          _cooking(id: 'cook', displayNumber: '18'),
          _completed(id: 'done', displayNumber: '18'),
        ],
      );
      _type(h.keypad, '18', _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.state.focusedOrderId, 'cook');
    });

    test('station filtering is respected', () async {
      final _Harness h = await _harness(
        orders: <Order>[
          _cooking(id: 'here', displayNumber: '18'),
          _cooking(id: 'other', displayNumber: '42', stationId: 'station-2'),
        ],
      );
      _type(h.keypad, '42', _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.state.focusedOrderId, isNull);
      expect(h.state.flash, 'No order #42');
    });

    test('displayNumber source matches displayNumber, not kotNumber', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'k', displayNumber: '5', kotNumber: '12')],
      );
      _type(h.keypad, '5', _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.state.focusedOrderId, 'k');

      h.keypad.handleKey(KeypadKey.dot, now: _t0);
      _type(h.keypad, '12', _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.state.focusedOrderId, isNull);
      expect(h.state.flash, 'No order #12');
    });

    test('KOT source matches kotNumber, not displayNumber', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'k', displayNumber: '5', kotNumber: '12')],
        titleSource: OrderTitleNumberSource.kotNumber,
      );
      _type(h.keypad, '12', _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.state.focusedOrderId, 'k');

      h.keypad.handleKey(KeypadKey.dot, now: _t0);
      _type(h.keypad, '5', _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.state.focusedOrderId, isNull);
      expect(h.state.flash, 'No order #5');
    });

    test(
      'KOT source falls back to displayNumber when kot is missing',
      () async {
        final _Harness h = await _harness(
          orders: <Order>[_cooking(id: 'k', displayNumber: '5')],
          titleSource: OrderTitleNumberSource.kotNumber,
        );
        _type(h.keypad, '5', _t0);
        h.keypad.handleKey(KeypadKey.enter, now: _t0);
        expect(h.state.focusedOrderId, 'k');
      },
    );

    test('stale buffer is discarded before the next digit', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
      );
      _type(h.keypad, '10', _t0);
      h.keypad.handleKey(
        KeypadKey.d8,
        now: _t0.add(const Duration(seconds: 3)),
      );
      expect(h.state.digits, '8');
    });

    test('digit at the exact timeout still appends', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
      );
      _type(h.keypad, '10', _t0);
      h.keypad.handleKey(
        KeypadKey.d8,
        now: _t0.add(KdsTiming.keypadBufferTimeout),
      );
      expect(h.state.digits, '108');
    });

    test('order-number buffer caps at 4 digits', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
      );
      _type(h.keypad, '12345', _t0);
      expect(h.state.digits, '1234');
    });

    test('item-index buffer caps at 2 digits', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
      );
      await _focus(h, '18');
      _type(h.keypad, '123', _t0);
      expect(h.state.digits, '12');
    });

    test(
      'expired flash is cleared on the next key using injected now',
      () async {
        final _Harness h = await _harness(
          orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
        );
        _type(h.keypad, '99', _t0);
        h.keypad.handleKey(KeypadKey.enter, now: _t0);
        expect(h.state.flash, 'No order #99');
        // Probes with `*`, which is inert on a calm board, so the only thing
        // under test is flash expiry against the injected clock.
        final DateTime until = _t0.add(KdsTiming.keypadFlashDuration);
        h.keypad.handleKey(
          KeypadKey.star,
          now: until.subtract(const Duration(milliseconds: 1)),
        );
        expect(h.state.flash, 'No order #99');
        h.keypad.handleKey(KeypadKey.star, now: until);
        expect(h.state.flash, isNull);
      },
    );
  });

  group('Enter', () {
    test('new order with no digits starts it', () async {
      final _Harness h = await _harness(
        orders: <Order>[_newOrder(id: 'n1', displayNumber: '10')],
      );
      await _focus(h, '10');
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      await _settle();
      expect(h.calls, contains('startOrder:n1'));
      expect(h.order('n1').status, OrderStatus.cooking);
    });

    test('cooking order with no digits completes it', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
      );
      await _focus(h, '18');
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      await _settle();
      expect(h.calls, contains('completeOrder:c1'));
      expect(h.order('c1').status, OrderStatus.completed);
    });

    test('completed order with no digits is a no-op', () async {
      final _Harness h = await _harness(
        orders: <Order>[_completed(id: 'd1', displayNumber: '20')],
        tab: KdsTab.completed,
      );
      await _focus(h, '20');
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.calls, isEmpty);
      expect(h.state.flash, 'Already completed');
      expect(h.order('d1').status, OrderStatus.completed);
    });

    test('cancelled order with no digits is a no-op', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cancelled(id: 'x1', displayNumber: '30')],
        tab: KdsTab.cancelled,
      );
      await _focus(h, '30');
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.calls, isEmpty);
      expect(h.state.flash, 'Order cancelled');
    });

    test(
      'new order + item index uses completeItems (start + complete)',
      () async {
        final _Harness h = await _harness(
          orders: <Order>[_newOrder(id: 'n1', displayNumber: '10')],
        );
        await _focus(h, '10');
        h.keypad.handleKey(KeypadKey.d1, now: _t0);
        h.keypad.handleKey(KeypadKey.enter, now: _t0);
        await _settle();
        expect(
          h.calls.any((String c) => c.startsWith('completeItems:n1/')),
          isTrue,
        );
        expect(h.order('n1').status, OrderStatus.cooking);
        expect(h.order('n1').items.first.isCompleted, isTrue);
      },
    );

    test('cooking + item index toggles that item', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
      );
      await _focus(h, '18');
      h.keypad.handleKey(KeypadKey.d1, now: _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      await _settle();
      expect(h.calls, contains('toggleItemCompleted:c1:c1-i1'));
      expect(h.order('c1').items.first.isCompleted, isTrue);
    });

    test('completed + item index is a no-op', () async {
      final _Harness h = await _harness(
        orders: <Order>[_completed(id: 'd1', displayNumber: '20')],
        tab: KdsTab.completed,
      );
      await _focus(h, '20');
      h.keypad.handleKey(KeypadKey.d1, now: _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.calls, isEmpty);
      expect(h.state.flash, 'Order closed');
    });

    test('cancelled + item index is a no-op', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cancelled(id: 'x1', displayNumber: '30')],
        tab: KdsTab.cancelled,
      );
      await _focus(h, '30');
      h.keypad.handleKey(KeypadKey.d1, now: _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.calls, isEmpty);
      expect(h.state.flash, 'Order closed');
    });

    test('removed item is a no-op', () async {
      final _Harness h = await _harness(
        orders: <Order>[
          _cooking(
            id: 'c1',
            displayNumber: '18',
            items: <OrderItem>[
              OrderItem(
                id: 'gone',
                productId: 'p1',
                nameSnapshot: 'Burger',
                quantity: 1,
                isRemoved: true,
              ),
            ],
          ),
        ],
      );
      await _focus(h, '18');
      h.keypad.handleKey(KeypadKey.d1, now: _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.calls, isEmpty);
      expect(h.state.flash, 'Item removed');
    });

    test('missing item index flashes', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
      );
      await _focus(h, '18');
      h.keypad.handleKey(KeypadKey.d9, now: _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.calls, isEmpty);
      expect(h.state.flash, 'No item 9');
    });

    test('missing focused order flashes and clears focus', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
      );
      await _focus(h, '18');
      h.ordersController.replaceAll(const <Order>[]);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.state.focusedOrderId, isNull);
      expect(h.state.flash, 'No order');
    });

    test('stale leftover + Enter is a no-op', () async {
      final _Harness h = await _harness(
        orders: <Order>[_newOrder(id: 'n1', displayNumber: '10')],
        staleIds: <String>{'n1'},
      );
      await _focus(h, '10');
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.calls, isEmpty);
      expect(h.state.flash, 'Use Clear (touch)');
    });

    test('stale leftover + item Enter is a no-op', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
        staleIds: <String>{'c1'},
      );
      await _focus(h, '18');
      h.keypad.handleKey(KeypadKey.d1, now: _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.calls, isEmpty);
      expect(h.state.flash, 'Use Clear (touch)');
    });

    test('on a calm board rings the first unstarted ticket', () async {
      final _Harness h = await _harness(
        orders: <Order>[
          _cooking(id: 'c1', displayNumber: '18'),
          _newOrder(
            id: 'n1',
            displayNumber: '19',
            createdAt: _t0.add(const Duration(minutes: 1)),
          ),
        ],
      );
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.state.focusedOrderId, 'n1');
      expect(h.state.flash, isNull);
      expect(h.calls, isEmpty);
    });

    test('on a calm board falls back to the first ticket', () async {
      final _Harness h = await _harness(
        orders: <Order>[
          _cooking(id: 'c1', displayNumber: '18'),
          _cooking(
            id: 'c2',
            displayNumber: '19',
            createdAt: _t0.add(const Duration(minutes: 1)),
          ),
        ],
      );
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.state.focusedOrderId, 'c1');
      expect(h.calls, isEmpty);
    });

    test('on a calm board skips a stale leftover', () async {
      final _Harness h = await _harness(
        orders: <Order>[
          _newOrder(id: 'old', displayNumber: '1'),
          _newOrder(
            id: 'fresh',
            displayNumber: '19',
            createdAt: _t0.add(const Duration(minutes: 1)),
          ),
        ],
        staleIds: <String>{'old'},
      );
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.state.focusedOrderId, 'fresh');
    });

    test('on an empty board does nothing', () async {
      final _Harness h = await _harness(orders: <Order>[]);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.state.focusedOrderId, isNull);
      expect(h.state.flash, isNull);
      expect(h.calls, isEmpty);
    });
  });

  group('* rollback', () {
    test('rolls back a focused completed order', () async {
      final _Harness h = await _harness(
        orders: <Order>[_completed(id: 'd1', displayNumber: '20')],
        tab: KdsTab.completed,
      );
      await _focus(h, '20');
      h.keypad.handleKey(KeypadKey.star, now: _t0);
      await _settle();
      expect(h.calls, contains('rollbackOrder:d1'));
      expect(h.order('d1').status, OrderStatus.cooking);
    });

    test(
      'is a no-op on new, cooking, cancelled, and nothing focused',
      () async {
        final _Harness h = await _harness(
          orders: <Order>[
            _newOrder(id: 'n1', displayNumber: '10'),
            _cooking(id: 'c1', displayNumber: '18'),
          ],
        );
        h.keypad.handleKey(KeypadKey.star, now: _t0);
        expect(h.calls, isEmpty);

        await _focus(h, '10');
        h.keypad.handleKey(KeypadKey.star, now: _t0);
        expect(h.calls, isEmpty);

        h.keypad.handleKey(KeypadKey.dot, now: _t0);
        h.keypad.handleKey(KeypadKey.dot, now: _t0);
        await _focus(h, '18');
        h.keypad.handleKey(KeypadKey.star, now: _t0);
        expect(h.calls, isEmpty);
      },
    );

    test('is a no-op on a focused cancelled order', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cancelled(id: 'x1', displayNumber: '30')],
        tab: KdsTab.cancelled,
      );
      await _focus(h, '30');
      h.keypad.handleKey(KeypadKey.star, now: _t0);
      expect(h.calls, isEmpty);
      expect(h.order('x1').status, OrderStatus.cancelled);
    });
  });

  group('+/-', () {
    test(
      'cycles tabs both ways, wraps, and clears the buffer on a calm board',
      () async {
        final _Harness h = await _harness(
          orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
        );
        h.keypad.handleKey(KeypadKey.d1, now: _t0);

        h.keypad.handleKey(KeypadKey.plus, now: _t0);
        expect(h.container.read(selectedKdsTabProvider), KdsTab.completed);
        expect(h.state.focusedOrderId, isNull);
        expect(h.state.digits, isEmpty);
        expect(h.state.flash, 'Completed tab');

        h.keypad.handleKey(KeypadKey.plus, now: _t0);
        expect(h.container.read(selectedKdsTabProvider), KdsTab.cancelled);
        h.keypad.handleKey(KeypadKey.plus, now: _t0);
        expect(h.container.read(selectedKdsTabProvider), KdsTab.cooking);

        h.keypad.handleKey(KeypadKey.minus, now: _t0);
        expect(h.container.read(selectedKdsTabProvider), KdsTab.cancelled);
        h.keypad.handleKey(KeypadKey.minus, now: _t0);
        expect(h.container.read(selectedKdsTabProvider), KdsTab.completed);
        h.keypad.handleKey(KeypadKey.minus, now: _t0);
        expect(h.container.read(selectedKdsTabProvider), KdsTab.cooking);
        expect(h.state.flash, 'Cooking tab');
      },
    );

    test('steps the ring along board order, leaving the tab alone', () async {
      final _Harness h = await _harness(
        orders: <Order>[
          _cooking(id: 'first', displayNumber: '18'),
          _cooking(
            id: 'second',
            displayNumber: '19',
            createdAt: _t0.add(const Duration(minutes: 1)),
          ),
        ],
      );
      await _focus(h, '18');
      h.keypad.handleKey(KeypadKey.d1, now: _t0);

      h.keypad.handleKey(KeypadKey.plus, now: _t0);
      expect(h.state.focusedOrderId, 'second');
      expect(h.state.digits, isEmpty);
      expect(h.container.read(selectedKdsTabProvider), KdsTab.cooking);

      h.keypad.handleKey(KeypadKey.minus, now: _t0);
      expect(h.state.focusedOrderId, 'first');
      expect(h.container.read(selectedKdsTabProvider), KdsTab.cooking);
    });

    test('stops at both ends with a flash and keeps the ring', () async {
      final _Harness h = await _harness(
        orders: <Order>[
          _cooking(id: 'first', displayNumber: '18'),
          _cooking(
            id: 'second',
            displayNumber: '19',
            createdAt: _t0.add(const Duration(minutes: 1)),
          ),
        ],
      );
      await _focus(h, '18');

      h.keypad.handleKey(KeypadKey.minus, now: _t0);
      expect(h.state.focusedOrderId, 'first');
      expect(h.state.flash, 'Start of board');
      expect(h.container.read(selectedKdsTabProvider), KdsTab.cooking);

      h.keypad.handleKey(KeypadKey.plus, now: _t0);
      h.keypad.handleKey(KeypadKey.plus, now: _t0);
      expect(h.state.focusedOrderId, 'second');
      expect(h.state.flash, 'End of board');
      expect(h.container.read(selectedKdsTabProvider), KdsTab.cooking);
    });

    test('follows newest-first ticket order', () async {
      final _Harness h = await _harness(
        orders: <Order>[
          _cooking(id: 'older', displayNumber: '18'),
          _cooking(
            id: 'newer',
            displayNumber: '19',
            createdAt: _t0.add(const Duration(minutes: 1)),
          ),
        ],
        ticketOrder: BoardTicketOrder.newestFirst,
      );
      await _focus(h, '19');
      h.keypad.handleKey(KeypadKey.plus, now: _t0);
      expect(h.state.focusedOrderId, 'older');
    });

    test('releasing the ring with . hands +/- back to the tabs', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
      );
      await _focus(h, '18');
      h.keypad.handleKey(KeypadKey.dot, now: _t0);
      expect(h.state.focusedOrderId, isNull);

      h.keypad.handleKey(KeypadKey.plus, now: _t0);
      expect(h.container.read(selectedKdsTabProvider), KdsTab.completed);
    });

    test('pages the sidebar and panel lists instead of cycling tabs', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
        quantities: _quantities(),
      );
      h.keypad.handleKey(KeypadKey.slash, now: _t0);
      expect(
        h.keypad.handleKey(KeypadKey.plus, now: _t0),
        const KeypadEffectPageList(1),
      );
      expect(
        h.keypad.handleKey(KeypadKey.minus, now: _t0),
        const KeypadEffectPageList(-1),
      );
      expect(h.container.read(selectedKdsTabProvider), KdsTab.cooking);

      h.keypad.handleKey(KeypadKey.d1, now: _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.state.surface, KeypadSurface.breakdownPanel);
      expect(
        h.keypad.handleKey(KeypadKey.plus, now: _t0),
        const KeypadEffectPageList(1),
      );
    });
  });

  group('.', () {
    test(
      'clears digits first, then flash, panel, sidebar, then focus',
      () async {
        final _Harness h = await _harness(
          orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
          quantities: _quantities(),
        );
        await _focus(h, '18');
        h.keypad.handleKey(KeypadKey.d1, now: _t0);
        expect(h.state.digits, '1');
        h.keypad.handleKey(KeypadKey.dot, now: _t0);
        expect(h.state.digits, isEmpty);
        expect(h.state.focusedOrderId, 'c1');

        h.keypad.handleKey(KeypadKey.d9, now: _t0);
        h.keypad.handleKey(KeypadKey.enter, now: _t0);
        expect(h.state.flash, 'No item 9');
        h.keypad.handleKey(KeypadKey.dot, now: _t0);
        expect(h.state.flash, isNull);
        expect(h.state.focusedOrderId, 'c1');

        h.keypad.handleKey(KeypadKey.slash, now: _t0);
        h.keypad.handleKey(KeypadKey.d1, now: _t0);
        expect(
          h.keypad.handleKey(KeypadKey.enter, now: _t0),
          const KeypadEffectOpenBreakdownPanel(_burgerKey),
        );
        expect(h.state.surface, KeypadSurface.breakdownPanel);
        expect(
          h.keypad.handleKey(KeypadKey.dot, now: _t0),
          const KeypadEffectCloseBreakdownPanel(),
        );
        expect(h.state.surface, KeypadSurface.sidebar);

        h.keypad.handleKey(KeypadKey.dot, now: _t0);
        expect(h.state.surface, KeypadSurface.board);
        expect(h.state.focusedOrderId, 'c1');

        h.keypad.handleKey(KeypadKey.dot, now: _t0);
        expect(h.state.focusedOrderId, isNull);

        h.keypad.handleKey(KeypadKey.dot, now: _t0);
        expect(h.state, KeypadState.initial);
      },
    );
  });

  group('/', () {
    test('toggles board and sidebar', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
      );
      h.keypad.handleKey(KeypadKey.slash, now: _t0);
      expect(h.state.surface, KeypadSurface.sidebar);
      h.keypad.handleKey(KeypadKey.slash, now: _t0);
      expect(h.state.surface, KeypadSurface.board);
    });

    test('no-ops with a flash when the sidebar is hidden', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
        sidebarVisible: false,
      );
      h.keypad.handleKey(KeypadKey.slash, now: _t0);
      expect(h.state.surface, KeypadSurface.board);
      expect(h.state.flash, 'Items list hidden');
    });

    test('no-ops while the breakdown panel is open', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
        quantities: _quantities(),
      );
      h.keypad.handleKey(KeypadKey.slash, now: _t0);
      h.keypad.handleKey(KeypadKey.d1, now: _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.state.surface, KeypadSurface.breakdownPanel);
      h.keypad.handleKey(KeypadKey.slash, now: _t0);
      expect(h.state.surface, KeypadSurface.breakdownPanel);
    });
  });

  group('sidebar and panel Enter', () {
    test('group index opens that group; missing group flashes', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
        quantities: _quantities(),
      );
      h.keypad.handleKey(KeypadKey.slash, now: _t0);
      h.keypad.handleKey(KeypadKey.d1, now: _t0);
      expect(
        h.keypad.handleKey(KeypadKey.enter, now: _t0),
        const KeypadEffectOpenBreakdownPanel(_burgerKey),
      );

      h.keypad.handleKey(KeypadKey.dot, now: _t0);
      h.keypad.handleKey(KeypadKey.d5, now: _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.state.flash, 'No item group 5');
    });

    test('Enter with no digits in the sidebar does nothing', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
        quantities: _quantities(),
      );
      h.keypad.handleKey(KeypadKey.slash, now: _t0);
      expect(
        h.keypad.handleKey(KeypadKey.enter, now: _t0),
        const KeypadEffectNone(),
      );
    });

    test('panel Enter with no digits completes all', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
        quantities: _quantities(),
      );
      h.keypad.handleKey(KeypadKey.slash, now: _t0);
      h.keypad.handleKey(KeypadKey.d1, now: _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(
        h.keypad.handleKey(KeypadKey.enter, now: _t0),
        const KeypadEffectCompleteAllPanelLines(),
      );
    });

    test(
      'panel line index completes that line; missing line flashes',
      () async {
        final _Harness h = await _harness(
          orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
          quantities: _quantities(),
        );
        h.keypad.handleKey(KeypadKey.slash, now: _t0);
        h.keypad.handleKey(KeypadKey.d1, now: _t0);
        h.keypad.handleKey(KeypadKey.enter, now: _t0);
        h.keypad.handleKey(KeypadKey.d1, now: _t0);
        expect(
          h.keypad.handleKey(KeypadKey.enter, now: _t0),
          const KeypadEffectCompletePanelLine(0),
        );

        h.keypad.handleKey(KeypadKey.d4, now: _t0);
        h.keypad.handleKey(KeypadKey.enter, now: _t0);
        expect(h.state.flash, 'No line 4');
      },
    );

    test('panel Complete all with nothing pending flashes', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
        quantities: _quantities(canComplete: false),
      );
      h.keypad.handleKey(KeypadKey.slash, now: _t0);
      h.keypad.handleKey(KeypadKey.d1, now: _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      h.keypad.handleKey(KeypadKey.enter, now: _t0);
      expect(h.state.flash, 'Nothing to complete');
    });
  });

  group('clearFocusIfMissing', () {
    test('clears focus when the order leaves the visible set', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
      );
      await _focus(h, '18');
      h.keypad.clearFocusIfMissing(<String>{});
      expect(h.state.focusedOrderId, isNull);
    });

    test('leaves focus alone when the order is still visible', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
      );
      await _focus(h, '18');
      h.keypad.clearFocusIfMissing(<String>{'c1', 'other'});
      expect(h.state.focusedOrderId, 'c1');
    });
  });

  group('notePanelOpened / notePanelClosed', () {
    test('are idempotent', () async {
      final _Harness h = await _harness(
        orders: <Order>[_cooking(id: 'c1', displayNumber: '18')],
      );
      h.keypad.notePanelOpened(_burgerKey);
      h.keypad.notePanelOpened(_burgerKey);
      expect(h.state.surface, KeypadSurface.breakdownPanel);
      expect(h.state.openGroupKey, _burgerKey);

      h.keypad.notePanelClosed();
      h.keypad.notePanelClosed();
      expect(h.state.surface, KeypadSurface.sidebar);
      expect(h.state.openGroupKey, isNull);
    });
  });
}

class _Harness {
  _Harness({required this.container, required this.ordersController});

  final ProviderContainer container;
  final _RecordingOrders ordersController;

  KeypadController get keypad => container.read(keypadProvider.notifier);

  KeypadState get state => container.read(keypadProvider);

  List<String> get calls => ordersController.calls;

  Order order(String id) {
    return container.read(orderByIdProvider(id)) ??
        (throw StateError('order $id missing'));
  }
}

class _RecordingOrders extends OrderController {
  _RecordingOrders(this._seed);

  final List<Order> _seed;
  final List<String> calls = <String>[];

  @override
  Future<List<Order>> build() async => List<Order>.of(_seed);

  void replaceAll(List<Order> next) {
    state = AsyncData<List<Order>>(next);
  }

  @override
  Future<void> startOrder(String orderId) async {
    calls.add('startOrder:$orderId');
    await super.startOrder(orderId);
  }

  @override
  Future<void> completeOrder(String orderId) async {
    calls.add('completeOrder:$orderId');
    await super.completeOrder(orderId);
  }

  @override
  Future<void> rollbackOrder(String orderId) async {
    calls.add('rollbackOrder:$orderId');
    await super.rollbackOrder(orderId);
  }

  @override
  Future<void> toggleItemCompleted(String orderId, String itemId) async {
    calls.add('toggleItemCompleted:$orderId:$itemId');
    await super.toggleItemCompleted(orderId, itemId);
  }

  @override
  Future<CompleteItemsResult> completeItems(
    List<({String orderId, String itemId})> targets,
  ) async {
    calls.add(
      'completeItems:${targets.map((t) => '${t.orderId}/${t.itemId}').join(',')}',
    );
    return super.completeItems(targets);
  }
}

Future<_Harness> _harness({
  required List<Order> orders,
  OrderTitleNumberSource titleSource = OrderTitleNumberSource.displayNumber,
  KdsTab tab = KdsTab.cooking,
  bool sidebarVisible = true,
  Set<String> staleIds = const <String>{},
  List<ItemQuantitySection>? quantities,
  BoardTicketOrder ticketOrder = BoardTicketOrder.oldestFirst,
}) async {
  final _RecordingOrders ordersController = _RecordingOrders(orders);
  final ProviderContainer container = ProviderContainer(
    overrides: [
      orderControllerProvider.overrideWith(() => ordersController),
      kdsClockProvider.overrideWith((Ref ref) => Stream<DateTime>.value(_t0)),
      orderTitleNumberSourceProvider.overrideWith((Ref ref) => titleSource),
      selectedKdsTabProvider.overrideWith((Ref ref) => tab),
      boardTicketOrderProvider.overrideWith((Ref ref) => ticketOrder),
      selectedStationProvider.overrideWith((Ref ref) => 'station-1'),
      productQuantityListVisibleProvider.overrideWith(
        (Ref ref) => sidebarVisible,
      ),
      staleLeftoverOrderIdsProvider.overrideWith((Ref ref) => staleIds),
      if (quantities != null)
        itemQuantitiesProvider.overrideWith((Ref ref) => quantities),
    ],
  );
  addTearDown(container.dispose);
  await container.read(orderControllerProvider.future);
  container.read(keypadProvider);
  return _Harness(container: container, ordersController: ordersController);
}

Future<void> _focus(_Harness h, String number) async {
  _type(h.keypad, number, _t0);
  h.keypad.handleKey(KeypadKey.enter, now: _t0);
  expect(h.state.focusedOrderId, isNotNull);
}

void _type(KeypadController keypad, String digits, DateTime now) {
  for (final String ch in digits.split('')) {
    keypad.handleKey(KeypadKey.values[int.parse(ch)], now: now);
  }
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

List<ItemQuantitySection> _quantities({bool canComplete = true}) {
  return <ItemQuantitySection>[
    ItemQuantitySection(
      category: flatSidebarCategory,
      entries: <ItemQuantityEntry>[
        ItemQuantityEntry(
          key: _burgerKey,
          quantity: 1,
          firstSeenAt: _t0,
          contributors: <PrepLine>[
            PrepLine(
              orderId: 'c1',
              itemId: 'c1-i1',
              displayNumber: '18',
              orderType: OrderType.dineIn,
              serviceLabel: 'Table - 05',
              quantity: 1,
              createdAt: _t0,
              productName: 'Burger',
              canComplete: canComplete,
              isCompleted: false,
            ),
          ],
        ),
      ],
    ),
  ];
}

Order _newOrder({
  required String id,
  required String displayNumber,
  String stationId = 'station-1',
  String? kotNumber,
  List<OrderItem>? items,
  DateTime? createdAt,
}) {
  return _order(
    id: id,
    displayNumber: displayNumber,
    status: OrderStatus.newOrder,
    stationId: stationId,
    kotNumber: kotNumber,
    items: items,
    createdAt: createdAt,
  );
}

Order _cooking({
  required String id,
  required String displayNumber,
  String stationId = 'station-1',
  String? kotNumber,
  List<OrderItem>? items,
  DateTime? createdAt,
}) {
  return _order(
    id: id,
    displayNumber: displayNumber,
    status: OrderStatus.cooking,
    stationId: stationId,
    kotNumber: kotNumber,
    items: items,
    createdAt: createdAt,
  );
}

Order _completed({required String id, required String displayNumber}) {
  return _order(
    id: id,
    displayNumber: displayNumber,
    status: OrderStatus.completed,
  );
}

Order _cancelled({required String id, required String displayNumber}) {
  return _order(
    id: id,
    displayNumber: displayNumber,
    status: OrderStatus.cancelled,
    cancelledAt: _t0,
  );
}

Order _order({
  required String id,
  required String displayNumber,
  required OrderStatus status,
  String stationId = 'station-1',
  String? kotNumber,
  DateTime? cancelledAt,
  List<OrderItem>? items,
  DateTime? createdAt,
}) {
  return Order(
    id: id,
    displayNumber: displayNumber,
    kotNumber: kotNumber,
    stationId: stationId,
    createdAt: createdAt ?? _t0,
    cancelledAt: cancelledAt,
    type: OrderType.dineIn,
    status: status,
    items:
        items ??
        <OrderItem>[
          OrderItem(
            id: '$id-i1',
            productId: 'p1',
            nameSnapshot: 'Burger',
            quantity: 1,
          ),
          OrderItem(
            id: '$id-i2',
            productId: 'p2',
            nameSnapshot: 'Fries',
            quantity: 1,
          ),
        ],
  );
}
