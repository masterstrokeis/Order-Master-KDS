import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_master_kds/controllers/auth_controller.dart';
import 'package:order_master_kds/controllers/order_controller.dart';
import 'package:order_master_kds/core/utils/order_column_packer.dart';
import 'package:order_master_kds/models/auth_session.dart';
import 'package:order_master_kds/models/complete_items_result.dart';
import 'package:order_master_kds/models/item_quantity.dart';
import 'package:order_master_kds/models/kds_api_error.dart';
import 'package:order_master_kds/models/kds_order_event.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/models/restaurant_model.dart';
import 'package:order_master_kds/models/staff_model.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/kds_api_service.dart';
import 'package:order_master_kds/services/kds_http_client.dart';

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

  group('order events stream', () {
    Future<List<KdsOrderEvent>> collectEvents(
      ProviderContainer container,
      Future<void> Function() action,
    ) async {
      final List<KdsOrderEvent> events = <KdsOrderEvent>[];
      final ProviderSubscription<AsyncValue<KdsOrderEvent>> subscription =
          container.listen<AsyncValue<KdsOrderEvent>>(
        orderEventsProvider,
        (AsyncValue<KdsOrderEvent>? previous, AsyncValue<KdsOrderEvent> next) {
          next.whenData(events.add);
        },
      );
      await action();
      await pumpEventQueue();
      subscription.close();
      return events;
    }

    test('replaceOrder inserting a new id emits newOrder', () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(orderControllerProvider.future);
      final OrderController controller = container.read(
        orderControllerProvider.notifier,
      );
      final Order template = container
          .read(orderControllerProvider)
          .requireValue
          .first;
      final Order incoming = template.copyWith(
        id: 'ord_new_ticket:station_grill',
        displayNumber: '99',
        status: OrderStatus.newOrder,
      );

      final List<KdsOrderEvent> events = await collectEvents(
        container,
        () async => controller.replaceOrder(incoming),
      );

      expect(events, hasLength(1));
      expect(events.single.kind, KdsOrderEventKind.newOrder);
      expect(events.single.orderId, incoming.id);
      expect(events.single.displayNumber, incoming.displayNumber);
    });

    test('replaceOrder cancelling an existing order emits cancelled', () async {
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

      final List<KdsOrderEvent> events = await collectEvents(
        container,
        () async => controller.replaceOrder(
          cooking.copyWith(status: OrderStatus.cancelled, version: cooking.version + 1),
        ),
      );

      expect(
        events.map((KdsOrderEvent e) => e.kind),
        contains(KdsOrderEventKind.cancelled),
      );
      expect(events.where((KdsOrderEvent e) => e.kind == KdsOrderEventKind.cancelled),
          hasLength(1));
      final Order cancelled = container
          .read(orderControllerProvider)
          .requireValue
          .firstWhere((Order o) => o.id == cooking.id);
      expect(cancelled.cancelledAt, isNotNull);
    });

    test('replaceOrder preserves cancelledAt across later patches', () async {
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
      final DateTime firstCancel = DateTime.utc(2026, 8, 14, 12, 0, 0);

      controller.replaceOrder(
        cooking.copyWith(
          status: OrderStatus.cancelled,
          version: cooking.version + 1,
          updatedAt: firstCancel,
        ),
      );
      final DateTime? stamped = container
          .read(orderControllerProvider)
          .requireValue
          .firstWhere((Order o) => o.id == cooking.id)
          .cancelledAt;
      expect(stamped, firstCancel);

      controller.replaceOrder(
        cooking.copyWith(
          status: OrderStatus.cancelled,
          version: cooking.version + 2,
          updatedAt: firstCancel.add(const Duration(seconds: 20)),
        ),
      );
      expect(
        container
            .read(orderControllerProvider)
            .requireValue
            .firstWhere((Order o) => o.id == cooking.id)
            .cancelledAt,
        firstCancel,
      );
    });

    test('replaceOrder skips a lower version snapshot', () async {
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

      controller.replaceOrder(
        cooking.copyWith(version: cooking.version + 2, note: 'newer'),
      );
      controller.replaceOrder(
        cooking.copyWith(version: cooking.version + 1, note: 'stale'),
      );

      final Order afterStale = container
          .read(orderControllerProvider)
          .requireValue
          .firstWhere((Order o) => o.id == cooking.id);
      expect(afterStale.note, 'newer');
      expect(afterStale.version, cooking.version + 2);

      controller.replaceOrder(
        cooking.copyWith(version: cooking.version + 3, note: 'newest'),
      );
      expect(
        container
            .read(orderControllerProvider)
            .requireValue
            .firstWhere((Order o) => o.id == cooking.id)
            .note,
        'newest',
      );
    });

    test('startOrder in offline/mock mode emits no events', () async {
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

      final List<KdsOrderEvent> events = await collectEvents(
        container,
        () => controller.startOrder(order.id),
      );

      expect(
        container
            .read(orderControllerProvider)
            .requireValue
            .firstWhere((Order o) => o.id == order.id)
            .status,
        OrderStatus.cooking,
      );
      expect(events, isEmpty);
    });

    test('toggleItemCompleted in offline/mock mode emits no events', () async {
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
      final OrderItem item = cooking.items.first;

      final List<KdsOrderEvent> events = await collectEvents(
        container,
        () => controller.toggleItemCompleted(cooking.id, item.id),
      );

      expect(
        container
            .read(orderControllerProvider)
            .requireValue
            .firstWhere((Order o) => o.id == cooking.id)
            .items
            .firstWhere((OrderItem i) => i.id == item.id)
            .isCompleted,
        !item.isCompleted,
      );
      expect(events, isEmpty);
    });

    test('VERSION_CONFLICT adoption emits an event', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_AuthenticatedAuthController.new),
          kdsApiServiceProvider.overrideWith(
            (Ref ref) => _VersionConflictApi(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(orderControllerProvider.future);
      final OrderController controller = container.read(
        orderControllerProvider.notifier,
      );
      final Order order = container
          .read(orderControllerProvider)
          .requireValue
          .firstWhere((Order o) => o.status == OrderStatus.newOrder);

      final List<KdsOrderEvent> events = await collectEvents(
        container,
        () => controller.startOrder(order.id),
      );

      expect(
        container
            .read(orderControllerProvider)
            .requireValue
            .firstWhere((Order o) => o.id == order.id)
            .status,
        OrderStatus.cancelled,
      );
      expect(controller.lastActionMessage, 'Order updated elsewhere');
      expect(
        events.map((KdsOrderEvent e) => e.kind),
        contains(KdsOrderEventKind.cancelled),
      );
    });
  });

  test('clearStationOrders empties the board without events or cursor change',
      () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(orderControllerProvider.future);
    final OrderController controller = container.read(
      orderControllerProvider.notifier,
    );
    controller.updateSyncCursor('cursor_keep');
    expect(container.read(orderControllerProvider).requireValue, isNotEmpty);
    expect(
      container.read(
        itemPrepBreakdownProvider(
          const ItemGroupKey(name: 'Salmon Grill', modifierText: ''),
        ),
      ),
      isNotEmpty,
    );

    final List<KdsOrderEvent> events = <KdsOrderEvent>[];
    final ProviderSubscription<AsyncValue<KdsOrderEvent>> subscription =
        container.listen<AsyncValue<KdsOrderEvent>>(
      orderEventsProvider,
      (AsyncValue<KdsOrderEvent>? previous, AsyncValue<KdsOrderEvent> next) {
        next.whenData(events.add);
      },
    );

    controller.clearStationOrders();
    await pumpEventQueue();
    subscription.close();

    expect(container.read(orderControllerProvider).requireValue, isEmpty);
    expect(controller.syncCursor, 'cursor_keep');
    expect(events, isEmpty);
    expect(container.read(ordersForCurrentViewProvider), isEmpty);
    expect(container.read(itemQuantitiesProvider), isEmpty);
    expect(
      container.read(
        itemPrepBreakdownProvider(
          const ItemGroupKey(name: 'Salmon Grill', modifierText: ''),
        ),
      ),
      isEmpty,
    );

    final PackedOrderBoard packed = packOrderColumns(
      orders: container.read(ordersForCurrentViewProvider),
      boardWidth: 1280,
      boardHeight: 800,
    );
    expect(
      packed.columns.every((List<CardSegment> column) => column.isEmpty),
      isTrue,
    );
  });

  group('stale leftover orders', () {
    test('markCurrentOrdersStale snapshots existing ids only', () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(orderControllerProvider.future);
      final OrderController controller = container.read(
        orderControllerProvider.notifier,
      );
      final List<String> existing = container
          .read(orderControllerProvider)
          .requireValue
          .map((Order o) => o.id)
          .toList();

      controller.markCurrentOrdersStale();

      for (final String id in existing) {
        expect(controller.isStaleLeftover(id), isTrue);
      }

      final Order template = container
          .read(orderControllerProvider)
          .requireValue
          .first;
      final Order incoming = template.copyWith(
        id: 'ord_new_day:station-1',
        displayNumber: 'N1',
        status: OrderStatus.newOrder,
      );
      controller.replaceOrder(incoming);

      expect(controller.isStaleLeftover(incoming.id), isFalse);
      for (final String id in existing) {
        expect(controller.isStaleLeftover(id), isTrue);
      }
    });

    test('dismissStaleOrder removes one leftover and ignores live ids',
        () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(orderControllerProvider.future);
      final OrderController controller = container.read(
        orderControllerProvider.notifier,
      );
      controller.markCurrentOrdersStale();
      final List<Order> before = container
          .read(orderControllerProvider)
          .requireValue;
      final String staleId = before.first.id;
      final int count = before.length;

      controller.dismissStaleOrder(staleId);

      final List<Order> after = container
          .read(orderControllerProvider)
          .requireValue;
      expect(after, hasLength(count - 1));
      expect(after.any((Order o) => o.id == staleId), isFalse);
      expect(controller.isStaleLeftover(staleId), isFalse);

      final Order live = after.first.copyWith(
        id: 'ord_live:station-1',
        displayNumber: 'L1',
      );
      controller.replaceOrder(live);
      controller.dismissStaleOrder(live.id);
      expect(
        container
            .read(orderControllerProvider)
            .requireValue
            .any((Order o) => o.id == live.id),
        isTrue,
      );
    });

    test('clearStationOrders and refresh clear the stale set', () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(orderControllerProvider.future);
      final OrderController controller = container.read(
        orderControllerProvider.notifier,
      );
      final String id = container
          .read(orderControllerProvider)
          .requireValue
          .first
          .id;
      controller.markCurrentOrdersStale();
      expect(controller.isStaleLeftover(id), isTrue);

      controller.clearStationOrders();
      expect(controller.isStaleLeftover(id), isFalse);

      await controller.refresh();
      final String reloaded = container
          .read(orderControllerProvider)
          .requireValue
          .first
          .id;
      controller.markCurrentOrdersStale();
      expect(controller.isStaleLeftover(reloaded), isTrue);
      await controller.refresh();
      expect(controller.isStaleLeftover(reloaded), isFalse);
    });

    test('completeOrder does not call the API for stale leftovers', () async {
      final _RecordingCompleteApi api = _RecordingCompleteApi();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            _AuthenticatedAuthController.new,
          ),
          kdsApiServiceProvider.overrideWith((Ref ref) => api),
        ],
      );
      addTearDown(container.dispose);
      await container.read(orderControllerProvider.future);
      final OrderController controller = container.read(
        orderControllerProvider.notifier,
      );
      final Order cooking = container
          .read(orderControllerProvider)
          .requireValue
          .firstWhere((Order o) => o.status == OrderStatus.cooking);

      controller.markCurrentOrdersStale();
      await controller.completeOrder(cooking.id);

      expect(api.completeCalls, 0);
      expect(
        container
            .read(orderControllerProvider)
            .requireValue
            .firstWhere((Order o) => o.id == cooking.id)
            .status,
        OrderStatus.cooking,
      );
    });
  });

  group('completeItems', () {
    test('marks every cooking contributor complete across orders', () async {
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
      final List<({String orderId, String itemId})> targets = cooking.items
          .where((OrderItem item) => !item.isCompleted && !item.isRemoved)
          .map(
            (OrderItem item) => (orderId: cooking.id, itemId: item.id),
          )
          .toList();

      final CompleteItemsResult result = await controller.completeItems(targets);

      expect(result.completed, targets.length);
      expect(result.failed, 0);
      expect(
        container
            .read(orderControllerProvider)
            .requireValue
            .firstWhere((Order o) => o.id == cooking.id)
            .items
            .every((OrderItem item) => item.isCompleted || item.isRemoved),
        isTrue,
      );
    });

    test('per-item complete leaves other group members incomplete', () async {
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
      final List<OrderItem> pending = cooking.items
          .where((OrderItem item) => !item.isCompleted && !item.isRemoved)
          .toList();
      expect(pending.length, greaterThan(1));

      await controller.toggleItemCompleted(cooking.id, pending.first.id);

      final Order updated = container
          .read(orderControllerProvider)
          .requireValue
          .firstWhere((Order o) => o.id == cooking.id);
      expect(
        updated.items.firstWhere((OrderItem i) => i.id == pending.first.id).isCompleted,
        isTrue,
      );
      expect(
        updated.items.firstWhere((OrderItem i) => i.id == pending[1].id).isCompleted,
        isFalse,
      );
    });

    test('starts a newOrder then marks that item complete', () async {
      final _RecordingItemPatchApi api = _RecordingItemPatchApi();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_AuthenticatedAuthController.new),
          kdsApiServiceProvider.overrideWith((Ref ref) => api),
        ],
      );
      addTearDown(container.dispose);
      await container.read(orderControllerProvider.future);
      final OrderController controller = container.read(
        orderControllerProvider.notifier,
      );
      final Order newOrder = container
          .read(orderControllerProvider)
          .requireValue
          .firstWhere((Order o) => o.status == OrderStatus.newOrder);
      final OrderItem item = newOrder.items.first;

      final CompleteItemsResult result = await controller.completeItems(<({
        String orderId,
        String itemId
      })>[
        (orderId: newOrder.id, itemId: item.id),
      ]);

      expect(api.startCalls, 1);
      expect(api.patchCalls, 1);
      expect(result.completed, 1);
      expect(result.skippedNotStarted, 0);
      expect(result.failed, 0);

      final Order updated = container
          .read(orderControllerProvider)
          .requireValue
          .firstWhere((Order o) => o.id == newOrder.id);
      expect(updated.status, OrderStatus.cooking);
      expect(
        updated.items.firstWhere((OrderItem i) => i.id == item.id).isCompleted,
        isTrue,
      );
      expect(
        updated.items.any(
          (OrderItem i) => i.id != item.id && !i.isCompleted && !i.isRemoved,
        ),
        isTrue,
      );
    });

    test('starts an unstarted order once for two items', () async {
      final _RecordingItemPatchApi api = _RecordingItemPatchApi();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_AuthenticatedAuthController.new),
          kdsApiServiceProvider.overrideWith((Ref ref) => api),
        ],
      );
      addTearDown(container.dispose);
      await container.read(orderControllerProvider.future);
      final OrderController controller = container.read(
        orderControllerProvider.notifier,
      );
      final Order newOrder = container
          .read(orderControllerProvider)
          .requireValue
          .firstWhere((Order o) => o.status == OrderStatus.newOrder);
      final List<OrderItem> pending = newOrder.items
          .where((OrderItem item) => !item.isCompleted && !item.isRemoved)
          .take(2)
          .toList();
      expect(pending.length, 2);

      final CompleteItemsResult result = await controller.completeItems(
        pending
            .map(
              (OrderItem item) => (orderId: newOrder.id, itemId: item.id),
            )
            .toList(),
      );

      expect(api.startCalls, 1);
      expect(api.patchCalls, 2);
      expect(result.completed, 2);
      expect(result.failed, 0);
    });

    test('start failure counts as failed and does not PATCH the item', () async {
      final _FailStartApi api = _FailStartApi();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_AuthenticatedAuthController.new),
          kdsApiServiceProvider.overrideWith((Ref ref) => api),
        ],
      );
      addTearDown(container.dispose);
      await container.read(orderControllerProvider.future);
      final OrderController controller = container.read(
        orderControllerProvider.notifier,
      );
      final Order newOrder = container
          .read(orderControllerProvider)
          .requireValue
          .firstWhere((Order o) => o.status == OrderStatus.newOrder);
      final OrderItem item = newOrder.items.first;

      final CompleteItemsResult result = await controller.completeItems(<({
        String orderId,
        String itemId
      })>[
        (orderId: newOrder.id, itemId: item.id),
      ]);

      expect(api.startCalls, 1);
      expect(api.patchCalls, 0);
      expect(result.completed, 0);
      expect(result.failed, 1);
      expect(result.failedDisplayNumbers, contains(newOrder.displayNumber));
    });

    test('continues batch after VERSION_CONFLICT and reports failure', () async {
      final _FailFirstItemPatchApi api = _FailFirstItemPatchApi();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_AuthenticatedAuthController.new),
          kdsApiServiceProvider.overrideWith((Ref ref) => api),
        ],
      );
      addTearDown(container.dispose);
      await container.read(orderControllerProvider.future);
      final OrderController controller = container.read(
        orderControllerProvider.notifier,
      );
      final Order cooking = container
          .read(orderControllerProvider)
          .requireValue
          .firstWhere((Order o) => o.status == OrderStatus.cooking);
      final List<OrderItem> pending = cooking.items
          .where((OrderItem item) => !item.isCompleted && !item.isRemoved)
          .toList();
      expect(pending.length, greaterThanOrEqualTo(2));

      final List<({String orderId, String itemId})> targets = pending
          .take(2)
          .map(
            (OrderItem item) => (orderId: cooking.id, itemId: item.id),
          )
          .toList();

      final CompleteItemsResult result = await controller.completeItems(targets);

      expect(api.patchCalls, 2);
      expect(result.completed, 1);
      expect(result.failed, 1);
      expect(result.failedDisplayNumbers, contains(cooking.displayNumber));
    });
  });
}

class _AuthenticatedAuthController extends AuthController {
  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      deviceId: 'device_test',
      session: AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        staff: const Staff(id: 'staff_1', name: 'Test', initials: 'T'),
        restaurant: const Restaurant(id: 'rest_001', name: 'Test'),
        outlet: const Outlet(id: '1', name: 'Main'),
      ),
    );
  }
}

class _RecordingCompleteApi extends KdsApiService {
  _RecordingCompleteApi() : super(useMockBackend: true);

  int completeCalls = 0;

  @override
  Future<OrderActionResult> completeOrder({
    required AuthSession session,
    required String deviceId,
    required Order order,
    required String idempotencyKey,
  }) async {
    completeCalls++;
    return super.completeOrder(
      session: session,
      deviceId: deviceId,
      order: order,
      idempotencyKey: idempotencyKey,
    );
  }
}

class _VersionConflictApi extends KdsApiService {
  _VersionConflictApi() : super(useMockBackend: true);

  @override
  Future<OrderActionResult> startOrder({
    required AuthSession session,
    required String deviceId,
    required Order order,
    required String idempotencyKey,
  }) async {
    throw KdsApiError(
      code: 'VERSION_CONFLICT',
      message: 'stale version',
      order: order.copyWith(
        status: OrderStatus.cancelled,
        version: order.version + 4,
      ),
    );
  }
}

class _FailStartApi extends KdsApiService {
  _FailStartApi() : super(useMockBackend: true);

  int startCalls = 0;
  int patchCalls = 0;

  @override
  Future<OrderActionResult> startOrder({
    required AuthSession session,
    required String deviceId,
    required Order order,
    required String idempotencyKey,
  }) async {
    startCalls++;
    throw KdsApiError(
      code: 'VERSION_CONFLICT',
      message: 'stale version',
      order: order.copyWith(
        status: OrderStatus.cancelled,
        version: order.version + 4,
      ),
    );
  }

  @override
  Future<ItemPatchResult> patchItemCompleted({
    required AuthSession session,
    required String deviceId,
    required Order order,
    required String itemId,
    required bool isCompleted,
    required String idempotencyKey,
  }) async {
    patchCalls++;
    return super.patchItemCompleted(
      session: session,
      deviceId: deviceId,
      order: order,
      itemId: itemId,
      isCompleted: isCompleted,
      idempotencyKey: idempotencyKey,
    );
  }
}

class _RecordingItemPatchApi extends KdsApiService {
  _RecordingItemPatchApi() : super(useMockBackend: true);

  int startCalls = 0;
  int patchCalls = 0;

  @override
  Future<OrderActionResult> startOrder({
    required AuthSession session,
    required String deviceId,
    required Order order,
    required String idempotencyKey,
  }) async {
    startCalls++;
    return super.startOrder(
      session: session,
      deviceId: deviceId,
      order: order,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<ItemPatchResult> patchItemCompleted({
    required AuthSession session,
    required String deviceId,
    required Order order,
    required String itemId,
    required bool isCompleted,
    required String idempotencyKey,
  }) async {
    patchCalls++;
    return super.patchItemCompleted(
      session: session,
      deviceId: deviceId,
      order: order,
      itemId: itemId,
      isCompleted: isCompleted,
      idempotencyKey: idempotencyKey,
    );
  }
}

class _FailFirstItemPatchApi extends KdsApiService {
  _FailFirstItemPatchApi() : super(useMockBackend: true);

  int patchCalls = 0;

  @override
  Future<ItemPatchResult> patchItemCompleted({
    required AuthSession session,
    required String deviceId,
    required Order order,
    required String itemId,
    required bool isCompleted,
    required String idempotencyKey,
  }) async {
    patchCalls++;
    if (patchCalls == 1) {
      throw KdsApiError(
        code: 'VERSION_CONFLICT',
        message: 'stale version',
        order: order.copyWith(version: order.version + 1),
      );
    }
    return super.patchItemCompleted(
      session: session,
      deviceId: deviceId,
      order: order,
      itemId: itemId,
      isCompleted: isCompleted,
      idempotencyKey: idempotencyKey,
    );
  }
}
