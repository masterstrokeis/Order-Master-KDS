import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/order_controller.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';

void main() {
  test('startOrder moves newOrder to cooking', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(orderControllerProvider.future);
    final OrderController controller = container.read(
      orderControllerProvider.notifier,
    );
    final Order order = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order o) => o.status == OrderStatus.newOrder);

    controller.startOrder(order.id);

    final Order updated = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order o) => o.id == order.id);
    expect(updated.status, OrderStatus.cooking);
  });

  test('completeOrder moves cooking to completed', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(orderControllerProvider.future);
    final OrderController controller = container.read(
      orderControllerProvider.notifier,
    );
    final Order order = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order o) => o.status == OrderStatus.cooking);

    controller.completeOrder(order.id);

    final Order updated = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order o) => o.id == order.id);
    expect(updated.status, OrderStatus.completed);
  });

  test('toggleItemCompleted only works while cooking', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(orderControllerProvider.future);
    final OrderController controller = container.read(
      orderControllerProvider.notifier,
    );

    final Order newOrder = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order o) => o.status == OrderStatus.newOrder);
    final OrderItem newItem = newOrder.items.first;
    controller.toggleItemCompleted(newOrder.id, newItem.id);
    expect(
      container
          .read(orderControllerProvider)
          .requireValue
          .firstWhere((Order o) => o.id == newOrder.id)
          .items
          .first
          .isCompleted,
      newItem.isCompleted,
    );

    final Order cooking = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order o) => o.status == OrderStatus.cooking);
    final OrderItem cookingItem = cooking.items.firstWhere(
      (OrderItem item) => !item.isCompleted,
    );
    controller.toggleItemCompleted(cooking.id, cookingItem.id);
    expect(
      container
          .read(orderControllerProvider)
          .requireValue
          .firstWhere((Order o) => o.id == cooking.id)
          .items
          .firstWhere((OrderItem item) => item.id == cookingItem.id)
          .isCompleted,
      isTrue,
    );
  });

  test('marking all items done does not complete the order', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(orderControllerProvider.future);
    final OrderController controller = container.read(
      orderControllerProvider.notifier,
    );
    final Order cooking = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order o) => o.status == OrderStatus.cooking);

    for (final OrderItem item in cooking.items) {
      if (!item.isCompleted) {
        controller.toggleItemCompleted(cooking.id, item.id);
      }
    }

    final Order updated = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order o) => o.id == cooking.id);
    expect(updated.status, OrderStatus.cooking);
    expect(updated.items.every((OrderItem item) => item.isCompleted), isTrue);
  });

  test('rollbackOrder moves completed to cooking and preserves items', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(orderControllerProvider.future);
    final OrderController controller = container.read(
      orderControllerProvider.notifier,
    );
    final Order completed = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order o) => o.status == OrderStatus.completed);
    final List<bool> itemFlagsBefore = completed.items
        .map((OrderItem item) => item.isCompleted)
        .toList();

    controller.rollbackOrder(completed.id);

    final Order updated = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order o) => o.id == completed.id);
    expect(updated.status, OrderStatus.cooking);
    expect(
      updated.items.map((OrderItem item) => item.isCompleted).toList(),
      itemFlagsBefore,
    );
  });

  test('rollbackOrder is a no-op for non-completed orders', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(orderControllerProvider.future);
    final OrderController controller = container.read(
      orderControllerProvider.notifier,
    );
    final Order cooking = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order o) => o.status == OrderStatus.cooking);

    controller.rollbackOrder(cooking.id);

    final Order updated = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order o) => o.id == cooking.id);
    expect(updated.status, OrderStatus.cooking);
  });
}
