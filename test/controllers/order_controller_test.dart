import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    await controller.startOrder(order.id);

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

    await controller.completeOrder(order.id);

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
    await controller.toggleItemCompleted(newOrder.id, newItem.id);
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
    final OrderItem cookingItem = cooking.items.first;
    await controller.toggleItemCompleted(cooking.id, cookingItem.id);
    expect(
      container
          .read(orderControllerProvider)
          .requireValue
          .firstWhere((Order o) => o.id == cooking.id)
          .items
          .firstWhere((OrderItem i) => i.id == cookingItem.id)
          .isCompleted,
      !cookingItem.isCompleted,
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
        await controller.toggleItemCompleted(cooking.id, item.id);
      }
    }

    final Order updated = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order o) => o.id == cooking.id);
    expect(updated.status, OrderStatus.cooking);
    expect(updated.items.every((OrderItem i) => i.isCompleted), isTrue);
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
    final List<bool> beforeFlags = completed.items
        .map((OrderItem i) => i.isCompleted)
        .toList();

    await controller.rollbackOrder(completed.id);

    final Order updated = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order o) => o.id == completed.id);
    expect(updated.status, OrderStatus.cooking);
    expect(
      updated.items.map((OrderItem i) => i.isCompleted).toList(),
      beforeFlags,
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

    await controller.rollbackOrder(cooking.id);

    final Order updated = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order o) => o.id == cooking.id);
    expect(updated.status, OrderStatus.cooking);
  });

  test('acknowledgeRemovedItem clears isRemovedUnseen only', () async {
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
    final OrderItem base = cooking.items.first;
    controller.replaceOrder(
      cooking.copyWith(
        items: cooking.items
            .map(
              (OrderItem i) => i.id == base.id
                  ? i.copyWith(isRemoved: true, isRemovedUnseen: true)
                  : i,
            )
            .toList(),
      ),
    );

    await controller.acknowledgeRemovedItem(cooking.id, base.id);

    final OrderItem updated = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order o) => o.id == cooking.id)
        .items
        .firstWhere((OrderItem i) => i.id == base.id);
    expect(updated.isRemoved, isTrue);
    expect(updated.isRemovedUnseen, isFalse);
  });
}
