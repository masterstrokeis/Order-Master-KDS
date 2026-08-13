import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/constants/kds_layout.dart';
import 'package:order_master_kds/core/theme/app_spacing.dart';
import 'package:order_master_kds/core/utils/order_column_packer.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/board_overflow_indicator.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/waiting_orders_panel.dart';

Order _order({
  required String id,
  required String displayNumber,
  required DateTime createdAt,
  required List<OrderItem> items,
  OrderType type = OrderType.dineIn,
  String? tableNumber = 'T3',
}) {
  return Order(
    id: id,
    displayNumber: displayNumber,
    stationId: 'station-1',
    createdAt: createdAt,
    type: type,
    status: OrderStatus.newOrder,
    tableNumber: tableNumber,
    items: items,
  );
}

OrderItem _item(String id, String name, {String? note, String? modifier}) {
  return OrderItem(
    id: id,
    productId: 'p-$id',
    nameSnapshot: name,
    quantity: 1,
    note: note,
    modifierText: modifier,
  );
}

void main() {
  testWidgets('overflow chip invokes onTap', (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardOverflowIndicator(
            count: 2,
            onTap: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('+2 more orders waiting'));
    expect(taps, 1);
  });

  testWidgets('opens token-sized waiting panel and closes from icon', (
    WidgetTester tester,
  ) async {
    const BoardLayoutConstraints constraints = BoardLayoutConstraints(
      boardWidth: 900,
      boardHeight: 120,
    );
    final Order older = _order(
      id: 'ord-1',
      displayNumber: '2',
      createdAt: DateTime(2026, 8, 10, 8, 2),
      items: <OrderItem>[
        _item('i1', 'BLUEBERRY BUBBLE TEA', note: 'extra ice'),
      ],
    );
    final Order newer = _order(
      id: 'ord-2',
      displayNumber: '3',
      createdAt: DateTime(2026, 8, 10, 8, 6),
      type: OrderType.takeOut,
      tableNumber: null,
      items: <OrderItem>[
        _item('i2', 'CHICKEN BURGER', modifier: 'No onion'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersForCurrentViewProvider.overrideWith(
            (Ref ref) => <Order>[older, newer],
          ),
          packedOrderBoardProvider(constraints).overrideWith(
            (Ref ref) => const PackedOrderBoard(
              columns: <List<CardSegment>>[
                <CardSegment>[],
                <CardSegment>[],
              ],
              columnWidth: 280,
              unplacedOrderIds: <String>['ord-1', 'ord-2'],
            ),
          ),
          kdsClockProvider.overrideWith(
            (Ref ref) => Stream<DateTime>.value(DateTime(2026, 8, 10, 8, 10)),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return TextButton(
                  onPressed: () {
                    showWaitingOrdersPanel(
                      context: context,
                      constraints: constraints,
                    );
                  },
                  child: const Text('Open waiting'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open waiting'));
    await tester.pumpAndSettle();

    expect(find.byType(WaitingOrdersPanel), findsOneWidget);
    expect(find.text('Waiting orders'), findsOneWidget);
    expect(find.text('2 waiting'), findsOneWidget);
    expect(find.text('Order #2'), findsOneWidget);
    expect(find.text('Order #3'), findsOneWidget);
    expect(find.textContaining('Table - T3'), findsOneWidget);
    expect(find.text('Take-Out'), findsOneWidget);
    expect(
      tester.getSize(find.byType(WaitingOrdersPanel)).width,
      KdsLayout.minimumColumnWidth + AppSpacing.pageMargin * 2,
    );

    // Oldest first: Order #2 appears above Order #3.
    final double y2 = tester.getTopLeft(find.text('Order #2')).dy;
    final double y3 = tester.getTopLeft(find.text('Order #3')).dy;
    expect(y2, lessThan(y3));

    await tester.tap(find.text('Order #2'));
    await tester.pumpAndSettle();
    expect(find.text('BLUEBERRY BUBBLE TEA'), findsOneWidget);
    expect(find.textContaining('extra ice'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(WaitingOrdersPanel), findsNothing);
  });

  testWidgets('waiting list drops orders when packing clears them', (
    WidgetTester tester,
  ) async {
    const BoardLayoutConstraints constraints = BoardLayoutConstraints(
      boardWidth: 900,
      boardHeight: 120,
    );
    final Order waiting = _order(
      id: 'ord-wait',
      displayNumber: '9',
      createdAt: DateTime(2026, 8, 10, 8, 0),
      items: <OrderItem>[_item('i9', 'SOUP')],
    );
    final StateProvider<List<String>> unplacedIdsProvider =
        StateProvider<List<String>>((Ref ref) => <String>['ord-wait']);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        ordersForCurrentViewProvider.overrideWith(
          (Ref ref) => <Order>[waiting],
        ),
        packedOrderBoardProvider(constraints).overrideWith((Ref ref) {
          final List<String> ids = ref.watch(unplacedIdsProvider);
          return PackedOrderBoard(
            columns: const <List<CardSegment>>[<CardSegment>[]],
            columnWidth: 280,
            unplacedOrderIds: ids,
          );
        }),
        kdsClockProvider.overrideWith(
          (Ref ref) => Stream<DateTime>.value(DateTime(2026, 8, 10, 8, 10)),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: WaitingOrdersPanel(constraints: constraints),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Order #9'), findsOneWidget);
    expect(find.text('Nothing waiting'), findsNothing);

    container.read(unplacedIdsProvider.notifier).state = <String>[];
    await tester.pump();

    expect(find.text('Nothing waiting'), findsOneWidget);
    expect(find.text('Order #9'), findsNothing);
  });
}
