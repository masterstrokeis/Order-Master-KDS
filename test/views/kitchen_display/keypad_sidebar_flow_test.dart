import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/keypad_controller.dart';
import 'package:order_master_kds/controllers/order_controller.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/models/complete_items_result.dart';
import 'package:order_master_kds/models/keypad_state.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/kitchen_display/kitchen_display_screen.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/product_prep_breakdown_panel.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/product_sidebar.dart';
import 'package:shared_preferences/shared_preferences.dart';

final DateTime _t0 = DateTime.utc(2026, 8, 18, 12);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('/ enters the sidebar with outline and group badges', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pump(
      tester,
      _RecordingOrders(_burgerFriesOrders()),
    );

    expect(find.byKey(const Key('sidebar-keyboard-focus')), findsNothing);
    expect(find.byKey(const Key('group-number-badge-1')), findsNothing);

    await _dispatchDown(tester, _slash);
    await _dispatchUp(tester, _slash);
    await tester.pump();

    expect(container.read(keypadProvider).surface, KeypadSurface.sidebar);
    expect(find.byKey(const Key('sidebar-keyboard-focus')), findsOneWidget);
    expect(find.byKey(const Key('group-number-badge-1')), findsOneWidget);
    expect(find.byKey(const Key('group-number-badge-2')), findsOneWidget);
  });

  testWidgets('digits plus Enter opens the matching group panel', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _RecordingOrders(_burgerFriesOrders()));

    await _enterSidebar(tester);
    await _typeDigits(tester, '2');
    await _dispatchDown(tester, _enter);
    await _dispatchUp(tester, _enter);
    await tester.pumpAndSettle();

    expect(find.byType(ProductPrepBreakdownPanel), findsOneWidget);
    expect(find.text('Fries'), findsWidgets);
    expect(find.byKey(const Key('line-number-badge-1')), findsOneWidget);
  });

  testWidgets(
    'line digit plus Enter completes that line through completeItems',
    (WidgetTester tester) async {
      final _RecordingOrders orders = _RecordingOrders(_burgerFriesOrders());
      await _pump(tester, orders);

      await _enterSidebar(tester);
      await _typeDigits(tester, '1');
      await _dispatchDown(tester, _enter);
      await _dispatchUp(tester, _enter);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('line-number-badge-1')), findsOneWidget);
      expect(find.byKey(const Key('line-number-badge-2')), findsOneWidget);

      await _typeDigits(tester, '2');
      await _dispatchDown(tester, _enter);
      await _dispatchUp(tester, _enter);
      await tester.pumpAndSettle();

      expect(orders.completeItemsCalls, <String>['c3/c3-i1']);
      expect(
        orders.calls.where((String c) => c.startsWith('completeItems')),
        hasLength(1),
      );
    },
  );

  testWidgets('Enter with no digits drives the existing Complete-all path', (
    WidgetTester tester,
  ) async {
    final _RecordingOrders orders = _RecordingOrders(_burgerFriesOrders());
    await _pump(tester, orders);

    await _enterSidebar(tester);
    await _typeDigits(tester, '1');
    await _dispatchDown(tester, _enter);
    await _dispatchUp(tester, _enter);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('complete-all-button')),
      findsOneWidget,
    );

    await _dispatchDown(tester, _enter);
    await _dispatchUp(tester, _enter);
    await tester.pumpAndSettle();

    expect(orders.completeItemsCalls, <String>['c1/c1-i1,c3/c3-i1']);
    expect(find.text('Completed 2 of 2.'), findsOneWidget);
  });

  testWidgets('+/- pages the sidebar list', (WidgetTester tester) async {
    await _pump(tester, _RecordingOrders(_manyNamedOrders(40)));

    await _enterSidebar(tester);

    final ScrollController sidebar = _scrollControllerOf(
      tester,
      find.byType(ProductSidebar),
    );
    expect(sidebar.offset, 0);

    await _dispatchDown(tester, _plus);
    await _dispatchUp(tester, _plus);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(sidebar.offset, greaterThan(0));
    final double paged = sidebar.offset;

    await _dispatchDown(tester, _minus);
    await _dispatchUp(tester, _minus);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(sidebar.offset, lessThan(paged));
  });

  testWidgets('+/- pages the panel line list', (WidgetTester tester) async {
    await _pump(tester, _RecordingOrders(_manySameNameOrders(40)));

    await _enterSidebar(tester);
    await _typeDigits(tester, '1');
    await _dispatchDown(tester, _enter);
    await _dispatchUp(tester, _enter);
    await tester.pumpAndSettle();

    final ScrollController panel = _scrollControllerOf(
      tester,
      find.byType(ProductPrepBreakdownPanel),
    );
    expect(panel.offset, 0);

    await _dispatchDown(tester, _plus);
    await _dispatchUp(tester, _plus);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(panel.offset, greaterThan(0));
    final double paged = panel.offset;

    await _dispatchDown(tester, _minus);
    await _dispatchUp(tester, _minus);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(panel.offset, lessThan(paged));
  });

  testWidgets('. closes the panel and returns to the board', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pump(
      tester,
      _RecordingOrders(_burgerFriesOrders()),
    );

    await _enterSidebar(tester);
    await _typeDigits(tester, '2');
    await _dispatchDown(tester, _enter);
    await _dispatchUp(tester, _enter);
    await tester.pumpAndSettle();
    expect(find.byType(ProductPrepBreakdownPanel), findsOneWidget);

    await _dispatchDown(tester, _dot);
    await _dispatchUp(tester, _dot);
    await tester.pumpAndSettle();

    expect(find.byType(ProductPrepBreakdownPanel), findsNothing);
    expect(container.read(keypadProvider).surface, KeypadSurface.sidebar);

    await _dispatchDown(tester, _dot);
    await _dispatchUp(tester, _dot);
    await tester.pump();

    expect(container.read(keypadProvider).surface, KeypadSurface.board);
    expect(container.read(keypadProvider).focusedOrderId, isNull);
    expect(container.read(keypadProvider).digits, isEmpty);
    expect(find.byKey(const Key('sidebar-keyboard-focus')), findsNothing);
  });
}

const (LogicalKeyboardKey, PhysicalKeyboardKey) _digit1 = (
  LogicalKeyboardKey.numpad1,
  PhysicalKeyboardKey.numpad1,
);
const (LogicalKeyboardKey, PhysicalKeyboardKey) _digit2 = (
  LogicalKeyboardKey.numpad2,
  PhysicalKeyboardKey.numpad2,
);
const (LogicalKeyboardKey, PhysicalKeyboardKey) _enter = (
  LogicalKeyboardKey.numpadEnter,
  PhysicalKeyboardKey.numpadEnter,
);
const (LogicalKeyboardKey, PhysicalKeyboardKey) _slash = (
  LogicalKeyboardKey.numpadDivide,
  PhysicalKeyboardKey.numpadDivide,
);
const (LogicalKeyboardKey, PhysicalKeyboardKey) _dot = (
  LogicalKeyboardKey.numpadDecimal,
  PhysicalKeyboardKey.numpadDecimal,
);
const (LogicalKeyboardKey, PhysicalKeyboardKey) _plus = (
  LogicalKeyboardKey.numpadAdd,
  PhysicalKeyboardKey.numpadAdd,
);
const (LogicalKeyboardKey, PhysicalKeyboardKey) _minus = (
  LogicalKeyboardKey.numpadSubtract,
  PhysicalKeyboardKey.numpadSubtract,
);

Future<void> _enterSidebar(WidgetTester tester) async {
  await _dispatchDown(tester, _slash);
  await _dispatchUp(tester, _slash);
  await tester.pump();
}

Future<void> _typeDigits(WidgetTester tester, String digits) async {
  for (final String ch in digits.split('')) {
    final (LogicalKeyboardKey, PhysicalKeyboardKey) key = switch (ch) {
      '1' => _digit1,
      '2' => _digit2,
      _ => throw ArgumentError.value(ch),
    };
    await _dispatchDown(tester, key);
    await _dispatchUp(tester, key);
  }
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
  final Finder panel = find.byKey(const Key('panel-keyboard-scope'));
  final Finder scope = find.byKey(const Key('kds-keyboard-scope'));
  final Focus focus = tester.widget<Focus>(
    panel.evaluate().isNotEmpty ? panel : scope,
  );
  focus.onKeyEvent!(focus.focusNode!, event);
}

ScrollController _scrollControllerOf(WidgetTester tester, Finder ancestor) {
  final Scrollable scrollable = tester.widget<Scrollable>(
    find.descendant(of: ancestor, matching: find.byType(Scrollable)).first,
  );
  return scrollable.controller!;
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
  final List<String> completeItemsCalls = <String>[];

  @override
  Future<List<Order>> build() async => List<Order>.of(_seed);

  @override
  Future<CompleteItemsResult> completeItems(
    List<({String orderId, String itemId})> targets,
  ) async {
    final String joined = targets
        .map(
          (({String orderId, String itemId}) t) => '${t.orderId}/${t.itemId}',
        )
        .join(',');
    calls.add('completeItems:$joined');
    completeItemsCalls.add(joined);
    return super.completeItems(targets);
  }
}

List<Order> _burgerFriesOrders() {
  return <Order>[
    _cooking(id: 'c1', displayNumber: '10', name: 'Burger', createdAt: _t0),
    _cooking(
      id: 'c2',
      displayNumber: '11',
      name: 'Fries',
      createdAt: _t0.add(const Duration(minutes: 1)),
    ),
    _cooking(
      id: 'c3',
      displayNumber: '12',
      name: 'Burger',
      createdAt: _t0.add(const Duration(minutes: 2)),
    ),
  ];
}

List<Order> _manyNamedOrders(int count) {
  return <Order>[
    for (int i = 0; i < count; i++)
      _cooking(
        id: 'n$i',
        displayNumber: '${100 + i}',
        name: 'Item ${i.toString().padLeft(2, '0')}',
        createdAt: _t0.add(Duration(seconds: i)),
      ),
  ];
}

List<Order> _manySameNameOrders(int count) {
  return <Order>[
    for (int i = 0; i < count; i++)
      _cooking(
        id: 's$i',
        displayNumber: '${200 + i}',
        name: 'Soup',
        createdAt: _t0.add(Duration(seconds: i)),
      ),
  ];
}

Order _cooking({
  required String id,
  required String displayNumber,
  required String name,
  required DateTime createdAt,
}) {
  return Order(
    id: id,
    displayNumber: displayNumber,
    stationId: 'station-1',
    createdAt: createdAt,
    type: OrderType.dineIn,
    status: OrderStatus.cooking,
    tableNumber: '3',
    items: <OrderItem>[
      OrderItem(
        id: '$id-i1',
        productId: 'p-$name',
        nameSnapshot: name,
        quantity: 1,
      ),
    ],
  );
}
