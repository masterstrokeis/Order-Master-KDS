import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_master_kds/controllers/order_controller.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/kitchen_display/kitchen_display_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const (LogicalKeyboardKey, PhysicalKeyboardKey) _dot = (
  LogicalKeyboardKey.numpadDecimal,
  PhysicalKeyboardKey.numpadDecimal,
);

Order _screenOrder() {
  return Order(
    id: 'n1',
    displayNumber: '10',
    stationId: 'station-1',
    createdAt: DateTime.utc(2026, 8, 18, 12),
    type: OrderType.dineIn,
    status: OrderStatus.cooking,
    tableNumber: '3',
    items: <OrderItem>[
      OrderItem(
        id: 'n1-i1',
        productId: 'p1',
        nameSnapshot: 'Burger',
        quantity: 1,
      ),
    ],
  );
}

class _RecordingOrders extends OrderController {
  _RecordingOrders(this._seed);
  final List<Order> _seed;

  @override
  Future<List<Order>> build() async => List<Order>.of(_seed);
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

void _dispatchDirect(WidgetTester tester, KeyEvent event) {
  final Focus focus = tester.widget<Focus>(
    find.byKey(const Key('kds-keyboard-scope')),
  );
  focus.onKeyEvent!(focus.focusNode!, event);
}

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 800));

  final OrderController orders = _RecordingOrders(<Order>[_screenOrder()]);

  final ProviderContainer container = ProviderContainer(
    overrides: [
      orderControllerProvider.overrideWith(() => orders),
      urgencySettingsServiceProvider.overrideWith(
        (Ref ref) => UrgencySettingsService(),
      ),
      urgencySettingsProvider.overrideWith(
        () => UrgencySettingsController(UrgencySettings.defaults),
      ),
      kdsClockProvider.overrideWith(
        (Ref ref) => Stream<DateTime>.value(DateTime.utc(2026, 8, 18, 12)),
      ),
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('keypad legend starts hidden and shows on first key', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.byKey(const Key('keypad-legend-bar')), findsNothing);

    await _dispatchDown(tester, _dot);

    expect(find.byKey(const Key('keypad-legend-bar')), findsOneWidget);
    expect(find.text('+/-  Tab'), findsOneWidget);
  });

  testWidgets('keypad legend auto-hides after 30s idle', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);
    await _dispatchDown(tester, _dot);

    expect(find.byKey(const Key('keypad-legend-bar')), findsOneWidget);

    await tester.pump(const Duration(seconds: 31));
    await tester.pump();

    expect(find.byKey(const Key('keypad-legend-bar')), findsNothing);
  });

  testWidgets('keypad legend timer resets on activity', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);
    await _dispatchDown(tester, _dot); // at t=0

    await tester.pump(const Duration(seconds: 25));
    expect(find.byKey(const Key('keypad-legend-bar')), findsOneWidget);

    await _dispatchDown(tester, _dot); // reset at t=25

    await tester.pump(const Duration(seconds: 29)); // t=54
    expect(find.byKey(const Key('keypad-legend-bar')), findsOneWidget);

    await tester.pump(const Duration(seconds: 2)); // t=56
    await tester.pump();
    expect(find.byKey(const Key('keypad-legend-bar')), findsNothing);
  });
}

