import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_master_kds/controllers/auth_controller.dart';
import 'package:order_master_kds/controllers/order_controller.dart';
import 'package:order_master_kds/models/auth_session.dart';
import 'package:order_master_kds/models/kds_api_error.dart';
import 'package:order_master_kds/models/kds_order_event.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/models/restaurant_model.dart';
import 'package:order_master_kds/models/staff_model.dart';
import 'package:order_master_kds/providers/kds_backend_providers.dart';
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
