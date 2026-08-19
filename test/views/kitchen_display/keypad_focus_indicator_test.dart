import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/keypad_controller.dart';
import 'package:order_master_kds/controllers/order_controller.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/core/utils/keypad_key_map.dart';
import 'package:order_master_kds/core/utils/order_column_packer.dart';
import 'package:order_master_kds/models/item_quantity.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/kitchen_display/kitchen_display_screen.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/order_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

final DateTime _t0 = DateTime.utc(2026, 8, 18, 12);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('focus ring appears only on the focused order', (
    WidgetTester tester,
  ) async {
    final Order focused = _cardOrder(id: 'c1', displayNumber: '18');
    final Order other = _cardOrder(id: 'c2', displayNumber: '19');
    final ProviderContainer container = await _pumpCards(
      tester,
      orders: <Order>[focused, other],
      segments: <CardSegment>[
        _primarySegment(focused.id),
        _primarySegment(other.id),
      ],
    );

    expect(find.byKey(const Key('order-keyboard-focus-c1')), findsNothing);
    expect(find.byKey(const Key('order-keyboard-focus-c2')), findsNothing);

    _focusNumber(container, '18');
    await tester.pump();

    expect(find.byKey(const Key('order-keyboard-focus-c1')), findsOneWidget);
    expect(find.byKey(const Key('order-keyboard-focus-c2')), findsNothing);
  });

  testWidgets('focus ring appears on both segments of a split order', (
    WidgetTester tester,
  ) async {
    final Order split = _cardOrder(
      id: 'split',
      displayNumber: '7',
      itemCount: 4,
    );
    final ProviderContainer container = await _pumpCards(
      tester,
      orders: <Order>[split],
      segments: <CardSegment>[
        _segment(
          orderId: split.id,
          segmentIndex: 0,
          itemStartIndex: 0,
          itemEndIndex: 2,
          isPrimary: true,
          isFinal: false,
          showOutgoingContinued: true,
        ),
        _segment(
          orderId: split.id,
          segmentIndex: 1,
          itemStartIndex: 2,
          itemEndIndex: 4,
          isPrimary: false,
          isFinal: true,
          showIncomingContinued: true,
        ),
      ],
    );

    _focusNumber(container, '7');
    await tester.pump();

    expect(
      find.byKey(const Key('order-keyboard-focus-split')),
      findsNWidgets(2),
    );
    expect(find.byKey(const Key('item-number-badge-split-1')), findsOneWidget);
    expect(find.byKey(const Key('item-number-badge-split-2')), findsOneWidget);
    expect(find.byKey(const Key('item-number-badge-split-3')), findsOneWidget);
    expect(find.byKey(const Key('item-number-badge-split-4')), findsOneWidget);
  });

  testWidgets('focus ring disappears on the next frame after period', (
    WidgetTester tester,
  ) async {
    final Order order = _cardOrder(id: 'c1', displayNumber: '18');
    final ProviderContainer container = await _pumpCards(
      tester,
      orders: <Order>[order],
      segments: <CardSegment>[_primarySegment(order.id)],
    );

    _focusNumber(container, '18');
    await tester.pump();
    expect(find.byKey(const Key('order-keyboard-focus-c1')), findsOneWidget);
    expect(find.byKey(const Key('item-number-badge-c1-1')), findsOneWidget);

    container.read(keypadProvider.notifier).handleKey(KeypadKey.dot, now: _t0);
    await tester.pump();

    expect(find.byKey(const Key('order-keyboard-focus-c1')), findsNothing);
    expect(find.byKey(const Key('item-number-badge-c1-1')), findsNothing);
  });

  testWidgets(
    'item-number-badge widgets are absent until the order is focused',
    (WidgetTester tester) async {
      final Order order = _cardOrder(
        id: 'c1',
        displayNumber: '18',
        itemCount: 2,
      );
      final ProviderContainer container = await _pumpCards(
        tester,
        orders: <Order>[order],
        segments: <CardSegment>[_segment(orderId: order.id, itemEndIndex: 2)],
      );

      expect(find.byKey(const Key('item-number-badge-c1-1')), findsNothing);
      expect(find.byKey(const Key('item-number-badge-c1-2')), findsNothing);

      _focusNumber(container, '18');
      await tester.pump();

      expect(find.byKey(const Key('item-number-badge-c1-1')), findsOneWidget);
      expect(find.byKey(const Key('item-number-badge-c1-2')), findsOneWidget);
    },
  );

  testWidgets('type-ahead pill shows 18_ then the not-found flash', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      _RecordingOrders(<Order>[
        _screenOrder(
          id: 'other',
          displayNumber: '99',
          status: OrderStatus.cooking,
        ),
      ]),
    );

    await _dispatchDown(tester, _digit1);
    await _dispatchUp(tester, _digit1);
    await _dispatchDown(tester, _digit8);
    await _dispatchUp(tester, _digit8);
    await tester.pump();

    expect(find.text('Order 18_'), findsOneWidget);

    await _dispatchDown(tester, _enter);
    await _dispatchUp(tester, _enter);
    await tester.pump();

    expect(find.text('No order #18'), findsOneWidget);
  });

  testWidgets('legend text changes across surfaces and order statuses', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pumpScreen(
      tester,
      _RecordingOrders(<Order>[
        _screenOrder(
          id: 'n1',
          displayNumber: '10',
          status: OrderStatus.newOrder,
        ),
        _screenOrder(
          id: 'c1',
          displayNumber: '18',
          status: OrderStatus.cooking,
        ),
        _screenOrder(
          id: 'done',
          displayNumber: '20',
          status: OrderStatus.completed,
          completedAt: _t0,
        ),
      ]),
    );

    expect(find.text('+/-  Tab'), findsOneWidget);
    expect(find.text('Enter  Pick ticket'), findsOneWidget);
    expect(find.text('0-9  Order #'), findsOneWidget);

    await _typeOrderNumber(tester, '10');
    expect(find.text('Enter  Start'), findsOneWidget);
    expect(find.text('0-9  Item #'), findsOneWidget);
    expect(find.text('+/-  Next ticket'), findsOneWidget);

    await _dispatchDown(tester, _dot);
    await _dispatchUp(tester, _dot);
    await tester.pump();

    await _typeOrderNumber(tester, '18');
    expect(find.text('Enter  Complete'), findsOneWidget);

    await _dispatchDown(tester, _dot);
    await _dispatchUp(tester, _dot);
    await tester.pump();

    container.read(selectedKdsTabProvider.notifier).state = KdsTab.completed;
    await tester.pumpAndSettle();
    await _typeOrderNumber(tester, '20');
    expect(find.text('Enter  —'), findsOneWidget);
    expect(find.text('*  Rollback'), findsOneWidget);

    await _dispatchDown(tester, _slash);
    await _dispatchUp(tester, _slash);
    await tester.pump();
    expect(find.text('+/-  Scroll items'), findsOneWidget);

    container
        .read(keypadProvider.notifier)
        .notePanelOpened(const ItemGroupKey(name: 'Burger', modifierText: ''));
    await tester.pump();
    expect(find.text('+/-  Scroll lines'), findsOneWidget);
  });
}

const (LogicalKeyboardKey, PhysicalKeyboardKey) _digit1 = (
  LogicalKeyboardKey.numpad1,
  PhysicalKeyboardKey.numpad1,
);
const (LogicalKeyboardKey, PhysicalKeyboardKey) _digit0 = (
  LogicalKeyboardKey.numpad0,
  PhysicalKeyboardKey.numpad0,
);
const (LogicalKeyboardKey, PhysicalKeyboardKey) _digit8 = (
  LogicalKeyboardKey.numpad8,
  PhysicalKeyboardKey.numpad8,
);
const (LogicalKeyboardKey, PhysicalKeyboardKey) _digit2 = (
  LogicalKeyboardKey.numpad2,
  PhysicalKeyboardKey.numpad2,
);
const (LogicalKeyboardKey, PhysicalKeyboardKey) _enter = (
  LogicalKeyboardKey.numpadEnter,
  PhysicalKeyboardKey.numpadEnter,
);
const (LogicalKeyboardKey, PhysicalKeyboardKey) _dot = (
  LogicalKeyboardKey.numpadDecimal,
  PhysicalKeyboardKey.numpadDecimal,
);
const (LogicalKeyboardKey, PhysicalKeyboardKey) _slash = (
  LogicalKeyboardKey.numpadDivide,
  PhysicalKeyboardKey.numpadDivide,
);

KeypadKey _digitKey(String ch) {
  return switch (ch) {
    '0' => KeypadKey.d0,
    '1' => KeypadKey.d1,
    '2' => KeypadKey.d2,
    '7' => KeypadKey.d7,
    '8' => KeypadKey.d8,
    '9' => KeypadKey.d9,
    _ => throw ArgumentError.value(ch),
  };
}

void _focusNumber(ProviderContainer container, String number) {
  final KeypadController keypad = container.read(keypadProvider.notifier);
  for (final String ch in number.split('')) {
    keypad.handleKey(_digitKey(ch), now: _t0);
  }
  keypad.handleKey(KeypadKey.enter, now: _t0);
}

Future<void> _typeOrderNumber(WidgetTester tester, String number) async {
  for (final String ch in number.split('')) {
    final (LogicalKeyboardKey, PhysicalKeyboardKey) key = switch (ch) {
      '1' => _digit1,
      '0' => _digit0,
      '8' => _digit8,
      '2' => _digit2,
      _ => throw ArgumentError.value(ch),
    };
    await _dispatchDown(tester, key);
    await _dispatchUp(tester, key);
  }
  await _dispatchDown(tester, _enter);
  await _dispatchUp(tester, _enter);
  await tester.pump();
}

Future<void> _dispatchDown(
  WidgetTester tester,
  (LogicalKeyboardKey, PhysicalKeyboardKey) key,
) async {
  _dispatchDirect(
    tester,
    KeyDownEvent(
      physicalKey: key.$2,
      logicalKey: key.$1,
      timeStamp: Duration.zero,
    ),
  );
  await tester.pump();
}

Future<void> _dispatchUp(
  WidgetTester tester,
  (LogicalKeyboardKey, PhysicalKeyboardKey) key,
) async {
  _dispatchDirect(
    tester,
    KeyUpEvent(
      physicalKey: key.$2,
      logicalKey: key.$1,
      timeStamp: Duration.zero,
    ),
  );
}

void _dispatchDirect(WidgetTester tester, KeyEvent event) {
  final Focus focus = tester.widget<Focus>(
    find.byKey(const Key('kds-keyboard-scope')),
  );
  focus.onKeyEvent!(focus.focusNode!, event);
}

Future<ProviderContainer> _pumpCards(
  WidgetTester tester, {
  required List<Order> orders,
  required List<CardSegment> segments,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      urgencySettingsServiceProvider.overrideWith(
        (Ref ref) => UrgencySettingsService(),
      ),
      urgencySettingsProvider.overrideWith(
        () => UrgencySettingsController(UrgencySettings.defaults),
      ),
      kdsClockProvider.overrideWith((Ref ref) => Stream<DateTime>.value(_t0)),
      ordersForCurrentViewProvider.overrideWith((Ref ref) => orders),
      orderByIdProvider.overrideWith((Ref ref, String id) {
        for (final Order order in orders) {
          if (order.id == id) {
            return order;
          }
        }
        return null;
      }),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: appLightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                for (final CardSegment segment in segments)
                  SizedBox(width: 280, child: OrderCard(segment: segment)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

Future<ProviderContainer> _pumpScreen(
  WidgetTester tester,
  _RecordingOrders orders,
) async {
  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  final ProviderContainer container = ProviderContainer(
    overrides: [
      orderControllerProvider.overrideWith(() => orders),
      urgencySettingsServiceProvider.overrideWith(
        (Ref ref) => UrgencySettingsService(),
      ),
      urgencySettingsProvider.overrideWith(
        () => UrgencySettingsController(UrgencySettings.defaults),
      ),
      kdsClockProvider.overrideWith((Ref ref) => Stream<DateTime>.value(_t0)),
      selectedStationProvider.overrideWith((Ref ref) => 'station-1'),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: appLightTheme,
        home: const KitchenDisplayScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

class _RecordingOrders extends OrderController {
  _RecordingOrders(this._seed);

  final List<Order> _seed;

  @override
  Future<List<Order>> build() async => List<Order>.of(_seed);
}

Order _cardOrder({
  required String id,
  required String displayNumber,
  int itemCount = 1,
}) {
  return Order(
    id: id,
    displayNumber: displayNumber,
    stationId: 'station-1',
    createdAt: _t0,
    type: OrderType.dineIn,
    status: OrderStatus.cooking,
    tableNumber: '3',
    items: <OrderItem>[
      for (int i = 0; i < itemCount; i++)
        OrderItem(
          id: '$id-i$i',
          productId: 'p-$i',
          nameSnapshot: 'Item $i',
          quantity: 1,
        ),
    ],
  );
}

Order _screenOrder({
  required String id,
  required String displayNumber,
  required OrderStatus status,
  DateTime? completedAt,
}) {
  return Order(
    id: id,
    displayNumber: displayNumber,
    stationId: 'station-1',
    createdAt: _t0,
    completedAt: completedAt,
    type: OrderType.dineIn,
    status: status,
    items: <OrderItem>[
      OrderItem(
        id: '$id-i1',
        productId: 'p1',
        nameSnapshot: 'Burger',
        quantity: 1,
      ),
    ],
  );
}

CardSegment _primarySegment(String orderId) {
  return _segment(orderId: orderId);
}

CardSegment _segment({
  required String orderId,
  int segmentIndex = 0,
  int itemStartIndex = 0,
  int itemEndIndex = 1,
  bool isPrimary = true,
  bool isFinal = true,
  bool showIncomingContinued = false,
  bool showOutgoingContinued = false,
}) {
  return CardSegment(
    orderId: orderId,
    segmentIndex: segmentIndex,
    itemStartIndex: itemStartIndex,
    itemEndIndex: itemEndIndex,
    isPrimary: isPrimary,
    isFinal: isFinal,
    showIncomingContinued: showIncomingContinued,
    showOutgoingContinued: showOutgoingContinued,
    estimatedHeight: 200,
  );
}
