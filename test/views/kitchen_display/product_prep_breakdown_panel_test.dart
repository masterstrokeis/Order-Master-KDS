import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/order_controller.dart';
import 'package:order_master_kds/core/constants/kds_layout.dart';
import 'package:order_master_kds/core/theme/app_spacing.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/views/kitchen_display/prep_line.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/product_prep_breakdown_panel.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/product_quantity_row.dart';

void main() {
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

  testWidgets('opens token-sized right panel and closes from icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return TextButton(
                  onPressed: () {
                    showProductPrepBreakdownPanel(
                      context: context,
                      productId: 'p-ceviche',
                      productName: 'Botica Ceviche',
                    );
                  },
                  child: const Text('Open breakdown'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open breakdown'));
    await tester.pumpAndSettle();

    expect(find.byType(ProductPrepBreakdownPanel), findsOneWidget);
    expect(find.text('Botica Ceviche'), findsWidgets);
    expect(find.textContaining('pending'), findsOneWidget);
    expect(
      tester.getSize(find.byType(ProductPrepBreakdownPanel)).width,
      KdsLayout.minimumColumnWidth + AppSpacing.pageMargin * 2,
    );

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductPrepBreakdownPanel), findsNothing);
  });

  testWidgets('barrier tap dismisses the breakdown', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return TextButton(
                  onPressed: () {
                    showProductPrepBreakdownPanel(
                      context: context,
                      productId: 'p-ceviche',
                      productName: 'Botica Ceviche',
                    );
                  },
                  child: const Text('Open breakdown'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open breakdown'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductPrepBreakdownPanel), findsOneWidget);

    await tester.tapAt(
      const Offset(AppSpacing.unit, AppSpacing.touchTargetMin),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProductPrepBreakdownPanel), findsNothing);
  });

  testWidgets('open panel updates to empty from canonical order changes', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    const String productId = 'p-miso-salmon';

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: ProductPrepBreakdownPanel(
              productId: productId,
              productName: 'Miso Salmon',
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    final List<PrepLine> before = container.read(
      productPrepBreakdownProvider(productId),
    );
    expect(before, isNotEmpty);
    expect(find.text('Nothing pending'), findsNothing);

    final OrderController controller = container.read(
      orderControllerProvider.notifier,
    );
    for (final String orderId
        in before.map((PrepLine line) => line.orderId).toSet()) {
      final Order order = container
          .read(orderControllerProvider)
          .requireValue
          .firstWhere((Order candidate) => candidate.id == orderId);
      if (order.status == OrderStatus.newOrder) {
        await controller.startOrder(orderId);
      }
      await controller.completeOrder(orderId);
    }
    await tester.pump();

    expect(find.text('0 pending'), findsOneWidget);
    expect(find.text('Nothing pending'), findsOneWidget);
  });
}
