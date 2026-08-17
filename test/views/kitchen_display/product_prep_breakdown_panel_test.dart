import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/models/item_quantity.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/views/kitchen_display/prep_line.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/product_prep_breakdown_panel.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/product_quantity_row.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/product_sidebar.dart';

const ItemGroupKey _panelKey = ItemGroupKey(
  name: 'Botica Ceviche',
  modifierText: '',
);

List<PrepLine> _samplePrepLines({required bool canComplete}) {
  return <PrepLine>[
    PrepLine(
      orderId: 'order-cooking',
      itemId: 'item-1',
      displayNumber: '101',
      orderType: OrderType.dineIn,
      serviceLabel: 'Table - 05',
      quantity: 2,
      createdAt: DateTime.utc(2026, 1, 1, 12),
      productName: 'Botica Ceviche',
      canComplete: canComplete,
      isCompleted: false,
    ),
    PrepLine(
      orderId: 'order-new',
      itemId: 'item-2',
      displayNumber: '102',
      orderType: OrderType.delivery,
      serviceLabel: 'Delivery',
      quantity: 1,
      createdAt: DateTime.utc(2026, 1, 1, 12, 5),
      productName: 'Botica Ceviche',
      modifierText: 'Extra lime',
      note: 'No onions',
      canComplete: canComplete,
      isCompleted: false,
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('zero-quantity product row is not tappable', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductQuantityRow(
            name: 'Coffee',
            quantity: 0,
            onTap: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Coffee'));
    expect(taps, 0);
  });

  testWidgets('sidebar shows ITEMS header', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemQuantitiesProvider.overrideWith(
            (Ref ref) => const <ItemQuantitySection>[],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ProductSidebar())),
      ),
    );
    await tester.pump();

    expect(find.text('ITEMS'), findsOneWidget);
    expect(find.text('PRODUCT'), findsNothing);
  });

  testWidgets('panel shows remaining count and complete actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kdsClockProvider.overrideWith(
            (Ref ref) => Stream<DateTime>.value(DateTime.utc(2026, 1, 1)),
          ),
          itemPrepBreakdownProvider.overrideWith(
            (Ref ref, ItemGroupKey key) =>
                key == _panelKey ? _samplePrepLines(canComplete: true) : const <PrepLine>[],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProductPrepBreakdownPanel(
              groupKey: _panelKey,
              displayTitle: 'Botica Ceviche',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Botica Ceviche'), findsWidgets);
    expect(find.text('3 remaining'), findsOneWidget);
    expect(find.text('Complete all'), findsOneWidget);
    expect(find.text('Complete'), findsNWidgets(2));
    expect(find.text('Extra lime'), findsOneWidget);
    expect(find.textContaining('No onions'), findsOneWidget);
  });

  testWidgets('panel shows nothing pending when breakdown is empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemPrepBreakdownProvider.overrideWith(
            (Ref ref, ItemGroupKey key) => const <PrepLine>[],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProductPrepBreakdownPanel(
              groupKey: _panelKey,
              displayTitle: 'Botica Ceviche',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('0 remaining'), findsOneWidget);
    expect(find.text('Nothing pending'), findsOneWidget);
    expect(find.text('Complete all'), findsNothing);
  });

  testWidgets('complete actions are enabled when tickets are not started', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemPrepBreakdownProvider.overrideWith(
            (Ref ref, ItemGroupKey key) =>
                key == _panelKey ? _samplePrepLines(canComplete: true) : const <PrepLine>[],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProductPrepBreakdownPanel(
              groupKey: _panelKey,
              displayTitle: 'Botica Ceviche',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Complete all'), findsOneWidget);
    expect(find.text('Complete'), findsNWidgets(2));

    final Finder disabledComplete = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextButton &&
          widget.onPressed == null &&
          widget.child is Text &&
          (widget.child! as Text).data == 'Complete',
    );
    expect(disabledComplete, findsNothing);

    final Finder enabledComplete = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextButton &&
          widget.onPressed != null &&
          widget.child is Text &&
          (widget.child! as Text).data == 'Complete',
    );
    expect(enabledComplete, findsNWidgets(2));
  });

  testWidgets('long panel title clamps to two lines', (
    WidgetTester tester,
  ) async {
    const String longTitle =
        'MANGO FALOODA-FALOODA EXTRA VERY LONG PRODUCT NAME';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemPrepBreakdownProvider.overrideWith(
            (Ref ref, ItemGroupKey key) =>
                key == _panelKey
                    ? _samplePrepLines(canComplete: true)
                    : const <PrepLine>[],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProductPrepBreakdownPanel(
              groupKey: _panelKey,
              displayTitle: longTitle,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Text title = tester.widget<Text>(find.text(longTitle));
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(find.text('Complete all'), findsOneWidget);
  });
}
