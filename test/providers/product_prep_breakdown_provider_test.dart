import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/order_controller.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/views/kitchen_display/prep_line.dart';

void main() {
  test(
    'breakdown reconciles with sidebar and excludes completed orders',
    () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(orderControllerProvider.future);

      const String productId = 'p-shrimp-taco';
      final List<PrepLine> lines = container.read(
        productPrepBreakdownProvider(productId),
      );
      final List<Order> orders = container
          .read(orderControllerProvider)
          .requireValue;
      final String? stationId = container.read(selectedStationProvider);

      final int sidebarQuantity = container
          .read(productQuantitiesProvider)
          .expand((ProductQuantitySection section) => section.entries)
          .firstWhere(
            (ProductQuantityEntry entry) => entry.product.id == productId,
          )
          .quantity;

      expect(
        lines.fold(0, (int total, PrepLine line) => total + line.quantity),
        sidebarQuantity,
      );
      for (final PrepLine line in lines) {
        final Order source = orders.firstWhere(
          (Order order) => order.id == line.orderId,
        );
        expect(source.stationId, stationId);
        expect(source.status, isNot(OrderStatus.completed));
      }
    },
  );

  test('breakdown is oldest first and retains display context', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(orderControllerProvider.future);

    final List<PrepLine> lines = container.read(
      productPrepBreakdownProvider('p-ceviche'),
    );

    expect(lines, isNotEmpty);
    for (int index = 1; index < lines.length; index++) {
      expect(
        lines[index - 1].createdAt.isAfter(lines[index].createdAt),
        isFalse,
      );
    }
    expect(
      lines.every((PrepLine line) => line.serviceLabel.isNotEmpty),
      isTrue,
    );
    expect(lines.every((PrepLine line) => line.productName.isNotEmpty), isTrue);
    expect(
      lines.any(
        (PrepLine line) => line.modifierText != null || line.note != null,
      ),
      isTrue,
    );
  });

  test('open breakdown reacts to canonical order status changes', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(orderControllerProvider.future);

    const String productId = 'p-shrimp-taco';
    final List<PrepLine> before = container.read(
      productPrepBreakdownProvider(productId),
    );
    final PrepLine target = before.first;
    final OrderController controller = container.read(
      orderControllerProvider.notifier,
    );
    final Order targetOrder = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order order) => order.id == target.orderId);

    if (targetOrder.status == OrderStatus.newOrder) {
      controller.startOrder(targetOrder.id);
    }
    controller.completeOrder(targetOrder.id);

    final List<PrepLine> after = container.read(
      productPrepBreakdownProvider(productId),
    );
    expect(
      after.where((PrepLine line) => line.orderId == target.orderId),
      isEmpty,
    );
  });
}
