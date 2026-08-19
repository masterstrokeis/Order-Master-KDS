import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/keypad_controller.dart';
import 'package:order_master_kds/controllers/order_controller.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/models/complete_items_result.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/kitchen_display/kitchen_display_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final DateTime _t0 = DateTime.utc(2026, 8, 18, 12);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('item toggle KeyDown fires once; Repeat and Up do not', (
    WidgetTester tester,
  ) async {
    final _RecordingOrders orders = _RecordingOrders(<Order>[
      _order(id: 'c1', displayNumber: '18', status: OrderStatus.cooking),
    ]);
    final ProviderContainer container = await _pump(tester, orders);

    await _typeOrderNumber(tester, '18');
    expect(container.read(keypadProvider).focusedOrderId, 'c1');

    await _dispatchDown(tester, _digit1);
    await _dispatchUp(tester, _digit1);
    await _dispatchDown(tester, _enter);
    expect(
      orders.calls.where((String c) => c.startsWith('toggleItemCompleted')),
      hasLength(1),
    );

    await _dispatchRepeat(tester, _enter);
    await _dispatchUp(tester, _enter);
    expect(
      orders.calls.where((String c) => c.startsWith('toggleItemCompleted')),
      hasLength(1),
    );
    expect(
      orders.calls.where((String c) => c.startsWith('completeOrder')),
      isEmpty,
    );
    expect(
      orders.calls.where((String c) => c.startsWith('startOrder')),
      isEmpty,
    );
  });

  testWidgets('Enter-as-Start KeyDown fires once; Repeat and Up do not', (
    WidgetTester tester,
  ) async {
    final _RecordingOrders orders = _RecordingOrders(<Order>[
      _order(id: 'n1', displayNumber: '10', status: OrderStatus.newOrder),
    ]);
    final ProviderContainer container = await _pump(tester, orders);

    await _typeOrderNumber(tester, '10');
    expect(container.read(keypadProvider).focusedOrderId, 'n1');

    await _dispatchDown(tester, _enter);
    expect(
      orders.calls.where((String c) => c.startsWith('startOrder')),
      hasLength(1),
    );

    await _dispatchRepeat(tester, _enter);
    await _dispatchUp(tester, _enter);
    expect(
      orders.calls.where((String c) => c.startsWith('startOrder')),
      hasLength(1),
    );
    expect(
      orders.calls.where((String c) => c.startsWith('completeOrder')),
      isEmpty,
    );
  });

  testWidgets('Enter-as-Complete KeyDown fires once; Repeat and Up do not', (
    WidgetTester tester,
  ) async {
    final _RecordingOrders orders = _RecordingOrders(<Order>[
      _order(id: 'c1', displayNumber: '18', status: OrderStatus.cooking),
    ]);
    final ProviderContainer container = await _pump(tester, orders);

    await _typeOrderNumber(tester, '18');
    expect(container.read(keypadProvider).focusedOrderId, 'c1');

    await _dispatchDown(tester, _enter);
    expect(
      orders.calls.where((String c) => c.startsWith('completeOrder')),
      hasLength(1),
    );

    await _dispatchRepeat(tester, _enter);
    await _dispatchUp(tester, _enter);
    expect(
      orders.calls.where((String c) => c.startsWith('completeOrder')),
      hasLength(1),
    );
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
const (LogicalKeyboardKey, PhysicalKeyboardKey) _enter = (
  LogicalKeyboardKey.numpadEnter,
  PhysicalKeyboardKey.numpadEnter,
);

Future<void> _typeOrderNumber(WidgetTester tester, String number) async {
  for (final String ch in number.split('')) {
    final (LogicalKeyboardKey, PhysicalKeyboardKey) key = switch (ch) {
      '1' => _digit1,
      '0' => _digit0,
      '8' => _digit8,
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

Future<void> _dispatchRepeat(
  WidgetTester tester,
  (LogicalKeyboardKey, PhysicalKeyboardKey) key,
) async {
  _dispatchDirect(
    tester,
    KeyRepeatEvent(
      physicalKey: key.$2,
      logicalKey: key.$1,
      timeStamp: Duration.zero,
    ),
  );
  await tester.pump();
}

void _dispatchDirect(WidgetTester tester, KeyEvent event) {
  final Focus focus = tester.widget<Focus>(
    find.byKey(const Key('kds-keyboard-scope')),
  );
  focus.onKeyEvent!(focus.focusNode!, event);
}

Future<ProviderContainer> _pump(
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
  final List<String> calls = <String>[];

  @override
  Future<List<Order>> build() async => List<Order>.of(_seed);

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
  Future<void> toggleItemCompleted(String orderId, String itemId) async {
    calls.add('toggleItemCompleted:$orderId:$itemId');
    await super.toggleItemCompleted(orderId, itemId);
  }

  @override
  Future<CompleteItemsResult> completeItems(
    List<({String orderId, String itemId})> targets,
  ) async {
    calls.add('completeItems');
    return super.completeItems(targets);
  }
}

Order _order({
  required String id,
  required String displayNumber,
  required OrderStatus status,
}) {
  return Order(
    id: id,
    displayNumber: displayNumber,
    stationId: 'station-1',
    createdAt: _t0,
    type: OrderType.dineIn,
    status: status,
    items: <OrderItem>[
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
