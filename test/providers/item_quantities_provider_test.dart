import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/order_controller.dart';
import 'package:order_master_kds/models/item_quantity.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/views/kitchen_display/prep_line.dart';

void main() {
  test('breakdown reconciles with sidebar remaining quantity', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(orderControllerProvider.future);

    const ItemGroupKey key = ItemGroupKey(
      name: 'Fried buffalo shrimp taco',
      modifierText: '',
    );
    final List<PrepLine> lines = container.read(itemPrepBreakdownProvider(key));
    final int sidebarQuantity = container
        .read(itemQuantitiesProvider)
        .expand((ItemQuantitySection section) => section.entries)
        .firstWhere((ItemQuantityEntry entry) => entry.key == key)
        .quantity;

    expect(
      lines.fold(0, (int total, PrepLine line) => total + line.quantity),
      sidebarQuantity,
    );
    for (final PrepLine line in lines) {
      final Order source = container
          .read(orderControllerProvider)
          .requireValue
          .firstWhere((Order order) => order.id == line.orderId);
      expect(source.status, isNot(OrderStatus.completed));
      expect(line.isCompleted, isFalse);
    }
  });

  test('breakdown is oldest first and retains display context', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(orderControllerProvider.future);

    const ItemGroupKey key = ItemGroupKey(
      name: 'Botica Ceviche',
      modifierText: '',
    );
    final List<PrepLine> lines = container.read(itemPrepBreakdownProvider(key));

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
    expect(lines.every((PrepLine line) => line.itemId.isNotEmpty), isTrue);
  });

  test('striking an item reduces sidebar remaining quantity', () async {
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
    final OrderItem target = cooking.items.firstWhere(
      (OrderItem item) => !item.isCompleted && !item.isRemoved,
    );
    final ItemGroupKey key = ItemGroupKey.fromItem(target);

    final int before = container
        .read(itemQuantitiesProvider)
        .expand((ItemQuantitySection section) => section.entries)
        .firstWhere((ItemQuantityEntry entry) => entry.key == key)
        .quantity;

    await controller.toggleItemCompleted(cooking.id, target.id);

    final int after = container
        .read(itemQuantitiesProvider)
        .expand((ItemQuantitySection section) => section.entries)
        .firstWhere((ItemQuantityEntry entry) => entry.key == key)
        .quantity;
    expect(after, before - target.quantity);
  });

  test('completing an order removes its items from sidebar', () async {
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
    final List<ItemGroupKey> keysBefore = container
        .read(itemQuantitiesProvider)
        .expand((ItemQuantitySection section) => section.entries)
        .where(
          (ItemQuantityEntry entry) => entry.contributors.any(
            (PrepLine line) => line.orderId == cooking.id,
          ),
        )
        .map((ItemQuantityEntry entry) => entry.key)
        .toList();
    expect(keysBefore, isNotEmpty);

    await controller.completeOrder(cooking.id);

    for (final OrderItem item in cooking.items) {
      if (item.isCompleted || item.isRemoved) {
        continue;
      }
      final ItemGroupKey key = ItemGroupKey.fromItem(item);
      final List<PrepLine> contributors = container
          .read(itemPrepBreakdownProvider(key));
      expect(
        contributors.any((PrepLine line) => line.orderId == cooking.id),
        isFalse,
      );
    }
  });

  test('removed item is excluded from sidebar totals', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(orderControllerProvider.future);
    final OrderController controller = container.read(
      orderControllerProvider.notifier,
    );
    final Order template = container.read(orderControllerProvider).requireValue.first;
    final OrderItem liveItem = _item(name: 'Removed Test');
    controller.replaceOrder(
      template.copyWith(
        id: 'ord-removed-test',
        displayNumber: 'R1',
        status: OrderStatus.cooking,
        items: <OrderItem>[liveItem],
      ),
    );

    final ItemGroupKey key = ItemGroupKey.fromItem(liveItem);
    expect(
      _quantityFor(container, key),
      liveItem.quantity,
    );

    controller.replaceOrder(
      template.copyWith(
        id: 'ord-removed-test',
        displayNumber: 'R1',
        status: OrderStatus.cooking,
        version: template.version + 1,
        items: <OrderItem>[liveItem.copyWith(isRemoved: true)],
      ),
    );

    expect(_quantityFor(container, key), 0);
  });

  test('quantity bump via replaceOrder updates sidebar total', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(orderControllerProvider.future);
    final OrderController controller = container.read(
      orderControllerProvider.notifier,
    );
    final Order template = container.read(orderControllerProvider).requireValue.first;
    final OrderItem liveItem = _item(name: 'Bump Test', quantity: 1);
    controller.replaceOrder(
      template.copyWith(
        id: 'ord-bump-test',
        displayNumber: 'B1',
        status: OrderStatus.cooking,
        items: <OrderItem>[liveItem],
      ),
    );

    final ItemGroupKey key = ItemGroupKey.fromItem(liveItem);
    expect(_quantityFor(container, key), 1);

    controller.replaceOrder(
      template.copyWith(
        id: 'ord-bump-test',
        displayNumber: 'B1',
        status: OrderStatus.cooking,
        version: template.version + 1,
        items: <OrderItem>[liveItem.copyWith(quantity: 4)],
      ),
    );

    expect(_quantityFor(container, key), 4);
  });

  test('unknown productId still appears in flat sidebar list via provider', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(orderControllerProvider.future);
    final OrderController controller = container.read(
      orderControllerProvider.notifier,
    );
    final Order template = container.read(orderControllerProvider).requireValue.first;
    controller.replaceOrder(
      template.copyWith(
        id: 'ord-unknown-product',
        displayNumber: 'U1',
        status: OrderStatus.cooking,
        items: <OrderItem>[
          _item(
            name: 'Backend Mismatch Item',
            productId: 'backend-only-id',
          ),
        ],
      ),
    );

    final List<ItemQuantityEntry> entries = container
        .read(itemQuantitiesProvider)
        .expand((ItemQuantitySection section) => section.entries)
        .toList();
    expect(
      entries.any(
        (ItemQuantityEntry entry) => entry.key.name == 'Backend Mismatch Item',
      ),
      isTrue,
    );
  });

  test('reappearing group sorts last after provider state changes', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(orderControllerProvider.future);
    final OrderController controller = container.read(
      orderControllerProvider.notifier,
    );
    final Order template = container.read(orderControllerProvider).requireValue.first;
    final DateTime older = DateTime.utc(2026, 1, 1, 10);
    final DateTime newer = DateTime.utc(2026, 1, 1, 14);

    controller.clearStationOrders();

    controller.replaceOrder(
      template.copyWith(
        id: 'ord-mango',
        displayNumber: 'M1',
        status: OrderStatus.cooking,
        createdAt: older,
        items: <OrderItem>[_item(name: 'Mango Juice', productId: 'p-mango')],
      ),
    );
    controller.replaceOrder(
      template.copyWith(
        id: 'ord-shawarma',
        displayNumber: 'S1',
        status: OrderStatus.cooking,
        createdAt: older.add(const Duration(minutes: 1)),
        items: <OrderItem>[_item(name: 'Shawarma', productId: 'p-shaw')],
      ),
    );

    List<String> names() => container
        .read(itemQuantitiesProvider)
        .expand((ItemQuantitySection section) => section.entries)
        .map((ItemQuantityEntry entry) => entry.key.name)
        .toList();

    expect(names(), equals(<String>['Mango Juice', 'Shawarma']));

    final Order shawarma = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order order) => order.id == 'ord-shawarma');
    for (final OrderItem item in shawarma.items) {
      await controller.toggleItemCompleted(shawarma.id, item.id);
    }
    expect(names(), equals(<String>['Mango Juice']));

    controller.replaceOrder(
      template.copyWith(
        id: 'ord-shawarma-return',
        displayNumber: 'S2',
        status: OrderStatus.cooking,
        createdAt: newer,
        items: <OrderItem>[_item(name: 'Shawarma', productId: 'p-shaw')],
      ),
    );

    expect(names(), equals(<String>['Mango Juice', 'Shawarma']));
  });

  test('open breakdown reacts to canonical order status changes', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(orderControllerProvider.future);

    const ItemGroupKey key = ItemGroupKey(
      name: 'Fried buffalo shrimp taco',
      modifierText: '',
    );
    final List<PrepLine> before = container.read(itemPrepBreakdownProvider(key));
    final PrepLine target = before.first;
    final OrderController controller = container.read(
      orderControllerProvider.notifier,
    );
    final Order targetOrder = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order order) => order.id == target.orderId);

    if (targetOrder.status == OrderStatus.newOrder) {
      await controller.startOrder(targetOrder.id);
    }
    await controller.completeOrder(targetOrder.id);

    final List<PrepLine> after = container.read(itemPrepBreakdownProvider(key));
    expect(
      after.where((PrepLine line) => line.orderId == target.orderId),
      isEmpty,
    );
  });
}

OrderItem _item({
  required String name,
  String productId = 'unknown-backend-id',
  int quantity = 1,
}) {
  return OrderItem(
    id: 'item-$name',
    productId: productId,
    nameSnapshot: name,
    quantity: quantity,
  );
}

int _quantityFor(ProviderContainer container, ItemGroupKey key) {
  return container
      .read(itemQuantitiesProvider)
      .expand((ItemQuantitySection section) => section.entries)
      .where((ItemQuantityEntry entry) => entry.key == key)
      .fold(0, (int total, ItemQuantityEntry entry) => total + entry.quantity);
}
