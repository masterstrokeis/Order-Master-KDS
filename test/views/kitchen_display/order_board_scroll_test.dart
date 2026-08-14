import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/core/utils/order_column_packer.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/order_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('extra columns scroll horizontally and are not in an overlay', (
    WidgetTester tester,
  ) async {
    await _pumpBoard(
      tester,
      orders: <Order>[
        _order('a', '1'),
        _order('b', '2'),
        _order('c', '3'),
        _order('d', '4'),
      ],
      boardWidth: 400,
      columns: <List<CardSegment>>[
        <CardSegment>[_segment('a')],
        <CardSegment>[_segment('b')],
        <CardSegment>[_segment('c')],
        <CardSegment>[_segment('d')],
      ],
    );

    expect(find.byType(Scrollable), findsWidgets);
    expect(find.text('Order #1'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Order #4')).dx, greaterThan(400));

    await tester.drag(find.text('Order #1'), const Offset(-800, 0));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Order #4')).dx, lessThan(400));
  });

  testWidgets('right More pages forward then left More pages back', (
    WidgetTester tester,
  ) async {
    await _pumpBoard(
      tester,
      orders: <Order>[
        _order('a', '1'),
        _order('b', '2'),
        _order('c', '3'),
        _order('d', '4'),
      ],
      boardWidth: 400,
      columns: <List<CardSegment>>[
        <CardSegment>[_segment('a')],
        <CardSegment>[_segment('b')],
        <CardSegment>[_segment('c')],
        <CardSegment>[_segment('d')],
      ],
    );

    expect(find.byKey(const Key('board-more-left')), findsNothing);
    expect(find.byKey(const Key('board-more-right')), findsOneWidget);

    await tester.tap(find.byKey(const Key('board-more-right')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('board-more-left')), findsOneWidget);

    int pages = 0;
    while (find.byKey(const Key('board-more-right')).evaluate().isNotEmpty &&
        pages < 8) {
      pages++;
      await tester.tap(find.byKey(const Key('board-more-right')));
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const Key('board-more-right')), findsNothing);
    expect(find.byKey(const Key('board-more-left')), findsOneWidget);
    expect(tester.getTopLeft(find.text('Order #4')).dx, lessThan(400));

    await tester.tap(find.byKey(const Key('board-more-left')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('board-more-right')), findsOneWidget);
  });

  testWidgets('hides More controls when all columns fit', (
    WidgetTester tester,
  ) async {
    await _pumpBoard(
      tester,
      orders: <Order>[_order('a', '1')],
      boardWidth: 1200,
      columnWidth: 280,
      columns: <List<CardSegment>>[
        <CardSegment>[_segment('a')],
      ],
    );

    expect(find.byKey(const Key('board-more-left')), findsNothing);
    expect(find.byKey(const Key('board-more-right')), findsNothing);
  });
}

Future<void> _pumpBoard(
  WidgetTester tester, {
  required List<Order> orders,
  required double boardWidth,
  required List<List<CardSegment>> columns,
  double boardHeight = 640,
  double columnWidth = 280,
}) async {
  await tester.binding.setSurfaceSize(Size(boardWidth, boardHeight));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    ProviderScope(
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
        packedOrderBoardProvider.overrideWith(
          (Ref ref, BoardLayoutConstraints constraints) {
            return PackedOrderBoard(
              columnWidth: columnWidth,
              columns: columns,
            );
          },
        ),
      ],
      child: MaterialApp(
        theme: appLightTheme,
        home: Scaffold(
          body: OrderBoard(
            boardWidth: boardWidth,
            boardHeight: boardHeight,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
