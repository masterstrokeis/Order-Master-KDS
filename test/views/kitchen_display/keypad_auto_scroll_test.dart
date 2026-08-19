import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/keypad_controller.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/core/utils/keypad_key_map.dart';
import 'package:order_master_kds/core/utils/order_column_packer.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/order_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

final DateTime _t0 = DateTime.utc(2026, 8, 18, 12);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'focusing an off-screen column order scrolls it into view without repacking',
    (WidgetTester tester) async {
      const double boardWidth = 400;
      const double boardHeight = 640;
      final ProviderContainer container = await _pumpBoard(
        tester,
        orders: <Order>[
          _order('a', '1'),
          _order('b', '2'),
          _order('c', '3'),
          _order('d', '4'),
        ],
        boardWidth: boardWidth,
        boardHeight: boardHeight,
        columns: <List<CardSegment>>[
          <CardSegment>[_segment('a')],
          <CardSegment>[_segment('b')],
          <CardSegment>[_segment('c')],
          <CardSegment>[_segment('d')],
        ],
      );

      expect(
        tester.getTopLeft(find.text('Order #4')).dx,
        greaterThan(boardWidth),
      );
      final OrderBoard before = tester.widget(find.byType(OrderBoard));
      expect(before.boardWidth, boardWidth);
      expect(before.boardHeight, boardHeight);

      final KeypadController keypad = container.read(keypadProvider.notifier);
      keypad.handleKey(KeypadKey.d4, now: _t0);
      keypad.handleKey(KeypadKey.enter, now: _t0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.getTopLeft(find.text('Order #4')).dx, lessThan(boardWidth));
      final OrderBoard after = tester.widget(find.byType(OrderBoard));
      expect(after.boardWidth, boardWidth);
      expect(after.boardHeight, boardHeight);
    },
  );

  testWidgets(
    'Enter then + walks the ring into an off-screen column, no number typed',
    (WidgetTester tester) async {
      const double boardWidth = 400;
      const double boardHeight = 640;
      final ProviderContainer container = await _pumpBoard(
        tester,
        orders: <Order>[
          _order('a', '1'),
          _order('b', '2'),
          _order('c', '3'),
          _order('d', '4'),
        ],
        boardWidth: boardWidth,
        boardHeight: boardHeight,
        columns: <List<CardSegment>>[
          <CardSegment>[_segment('a')],
          <CardSegment>[_segment('b')],
          <CardSegment>[_segment('c')],
          <CardSegment>[_segment('d')],
        ],
      );

      expect(
        tester.getTopLeft(find.text('Order #4')).dx,
        greaterThan(boardWidth),
      );

      final KeypadController keypad = container.read(keypadProvider.notifier);
      keypad.handleKey(KeypadKey.enter, now: _t0);
      await tester.pump();
      expect(container.read(keypadProvider).focusedOrderId, 'a');

      for (int i = 0; i < 3; i++) {
        keypad.handleKey(KeypadKey.plus, now: _t0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
      }

      expect(container.read(keypadProvider).focusedOrderId, 'd');
      expect(tester.getTopLeft(find.text('Order #4')).dx, lessThan(boardWidth));

      final OrderBoard after = tester.widget(find.byType(OrderBoard));
      expect(after.boardWidth, boardWidth);
      expect(after.boardHeight, boardHeight);
    },
  );
}

Order _order(String id, String displayNumber) {
  return Order(
    id: id,
    displayNumber: displayNumber,
    stationId: 'station-1',
    createdAt: DateTime.utc(2026, 8, 14, 12),
    type: OrderType.dineIn,
    status: OrderStatus.cooking,
    tableNumber: '3',
    items: <OrderItem>[
      OrderItem(
        id: 'item-$id',
        productId: 'p-1',
        nameSnapshot: 'Burger',
        quantity: 1,
      ),
    ],
  );
}

CardSegment _segment(String orderId) {
  return CardSegment(
    orderId: orderId,
    segmentIndex: 0,
    itemStartIndex: 0,
    itemEndIndex: 1,
    isPrimary: true,
    isFinal: true,
    showIncomingContinued: false,
    showOutgoingContinued: false,
    estimatedHeight: 200,
  );
}

Future<ProviderContainer> _pumpBoard(
  WidgetTester tester, {
  required List<Order> orders,
  required double boardWidth,
  required double boardHeight,
  required List<List<CardSegment>> columns,
  double columnWidth = 280,
}) async {
  await tester.binding.setSurfaceSize(Size(boardWidth, boardHeight));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  final ProviderContainer container = ProviderContainer(
    overrides: [
      urgencySettingsServiceProvider.overrideWith(
        (Ref ref) => UrgencySettingsService(),
      ),
      urgencySettingsProvider.overrideWith(
        () => UrgencySettingsController(UrgencySettings.defaults),
      ),
      kdsClockProvider.overrideWith(
        (Ref ref) => Stream<DateTime>.value(DateTime.utc(2026, 8, 14, 12)),
      ),
      ordersForCurrentViewProvider.overrideWith((Ref ref) => orders),
      orderByIdProvider.overrideWith((Ref ref, String id) {
        for (final Order order in orders) {
          if (order.id == id) {
            return order;
          }
        }
        return null;
      }),
      packedOrderBoardProvider.overrideWith((
        Ref ref,
        BoardLayoutConstraints constraints,
      ) {
        return PackedOrderBoard(columnWidth: columnWidth, columns: columns);
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
          body: OrderBoard(boardWidth: boardWidth, boardHeight: boardHeight),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
