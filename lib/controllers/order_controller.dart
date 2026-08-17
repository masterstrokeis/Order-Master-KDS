import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/cancelled_cooking_visibility.dart';
import '../core/utils/order_event_diff.dart';
import '../models/auth_session.dart';
import '../models/kds_api_error.dart';
import '../models/kds_order_event.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../models/orders_list_result.dart';
import '../models/sync_result.dart';
import '../providers/kds_backend_providers.dart';
import '../services/kds_api_service.dart';
import '../services/kds_http_client.dart';
import '../services/mock_orders_service.dart';
import 'auth_controller.dart';

class OrderController extends AsyncNotifier<List<Order>> {
  final Uuid _uuid = const Uuid();
  String? _syncCursor;
  String? _lastActionMessage;
  Set<String> _staleOrderIds = <String>{};

  String? get syncCursor => _syncCursor;
  String? get lastActionMessage => _lastActionMessage;

  bool isStaleLeftover(String orderId) => _staleOrderIds.contains(orderId);

  void _publishStaleIds() {
    ref.read(staleLeftoverOrderIdsProvider.notifier).state =
        Set<String>.of(_staleOrderIds);
  }

  KdsApiService get _api => ref.read(kdsApiServiceProvider);

  AuthSession? get _session => ref.read(authControllerProvider).session;

  String? get _deviceId => ref.read(authControllerProvider).deviceId;

  String? get _stationId => ref.read(selectedStationProvider);

  @override
  Future<List<Order>> build() async {
    return _loadOrders();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<Order>>();
    state = await AsyncValue.guard(_loadOrders);
    _publishStaleIds();
  }

  Future<List<Order>> _loadOrders() async {
    _staleOrderIds = <String>{};
    final AuthSession? session = _session;
    final String? deviceId = _deviceId;
    final String? stationId = _stationId;

    if (session == null || deviceId == null || stationId == null) {
      final List<Order> mock = await const MockOrdersService().fetchOrders();
      return mock.map(stampCancelledAt).toList();
    }

    final OrdersListResult active = await _api.listOrders(
      session: session,
      deviceId: deviceId,
      stationId: stationId,
      status: 'active',
    );
    final OrdersListResult completed = await _api.listOrders(
      session: session,
      deviceId: deviceId,
      stationId: stationId,
      status: 'completed',
    );

    _syncCursor = active.syncCursor;
    final Map<String, Order> byId = <String, Order>{
      for (final Order order in active.orders) order.id: order,
      for (final Order order in completed.orders) order.id: order,
    };
    return byId.values
        .map((Order order) => stampCancelledAt(order))
        .toList();
  }

  Future<void> startOrder(String orderId) async {
    if (isStaleLeftover(orderId)) {
      return;
    }
    await _runOrderAction(
      orderId: orderId,
      allowedFrom: OrderStatus.newOrder,
      call: (AuthSession session, String deviceId, Order order, String key) {
        return _api.startOrder(
          session: session,
          deviceId: deviceId,
          order: order,
          idempotencyKey: key,
        );
      },
    );
  }

  Future<void> completeOrder(String orderId) async {
    if (isStaleLeftover(orderId)) {
      return;
    }
    await _runOrderAction(
      orderId: orderId,
      allowedFrom: OrderStatus.cooking,
      call: (AuthSession session, String deviceId, Order order, String key) {
        return _api.completeOrder(
          session: session,
          deviceId: deviceId,
          order: order,
          idempotencyKey: key,
        );
      },
    );
  }

  Future<void> rollbackOrder(String orderId) async {
    if (isStaleLeftover(orderId)) {
      return;
    }
    await _runOrderAction(
      orderId: orderId,
      allowedFrom: OrderStatus.completed,
      call: (AuthSession session, String deviceId, Order order, String key) {
        return _api.rollbackOrder(
          session: session,
          deviceId: deviceId,
          order: order,
          idempotencyKey: key,
        );
      },
    );
  }

  Future<void> toggleItemCompleted(String orderId, String itemId) async {
    final List<Order>? orders = state.value;
    if (orders == null) {
      return;
    }

    final Order? order = _find(orders, orderId);
    if (order == null ||
        order.status != OrderStatus.cooking ||
        isStaleLeftover(orderId)) {
      return;
    }

    final OrderItem? item = _findItem(order, itemId);
    if (item == null || item.isRemoved) {
      return;
    }

    final AuthSession? session = _session;
    final String? deviceId = _deviceId;
    final String key = _uuid.v4();

    if (session == null || deviceId == null) {
      _replaceLocal(
        order.copyWith(
          items: order.items.map((OrderItem i) {
            if (i.id != itemId) {
              return i;
            }
            final bool next = !i.isCompleted;
            return i.copyWith(isCompleted: next, isNew: next ? false : i.isNew);
          }).toList(),
        ),
      );
      return;
    }

    try {
      final ItemPatchResult result = await _api.patchItemCompleted(
        session: session,
        deviceId: deviceId,
        order: order,
        itemId: itemId,
        isCompleted: !item.isCompleted,
        idempotencyKey: key,
      );
      _applyItemPatch(result);
      _lastActionMessage = null;
    } on KdsApiError catch (error) {
      await _handleMutationError(error);
    }
  }

  Future<void> acknowledgeRemovedItem(String orderId, String itemId) async {
    final List<Order>? orders = state.value;
    if (orders == null) {
      return;
    }

    final Order? order = _find(orders, orderId);
    if (order == null || isStaleLeftover(orderId)) {
      return;
    }
    final OrderItem? item = _findItem(order, itemId);
    if (item == null || !item.isRemoved || !item.isRemovedUnseen) {
      return;
    }

    final AuthSession? session = _session;
    final String? deviceId = _deviceId;
    final String key = _uuid.v4();

    if (session == null || deviceId == null) {
      _replaceLocal(
        order.copyWith(
          items: order.items
              .map(
                (OrderItem i) => i.id == itemId
                    ? i.copyWith(isRemovedUnseen: false)
                    : i,
              )
              .toList(),
        ),
      );
      return;
    }

    try {
      final ItemPatchResult result = await _api.acknowledgeRemovedItem(
        session: session,
        deviceId: deviceId,
        order: order,
        itemId: itemId,
        idempotencyKey: key,
      );
      _applyItemPatch(result);
      _lastActionMessage = null;
    } on KdsApiError catch (error) {
      await _handleMutationError(error);
    }
  }

  /// Full-state replace from WebSocket / sync (keyed by opaque order id).
  ///
  /// Skips a snapshot whose [Order.version] is older than the ticket already
  /// on the board so a delayed `/sync` event cannot wipe a newer live update.
  void replaceOrder(Order order) {
    final List<Order> current = state.value ?? <Order>[];
    final int index = current.indexWhere((Order o) => o.id == order.id);
    if (index >= 0 && order.version < current[index].version) {
      return;
    }
    _replaceLocal(order, insertIfMissing: true, emitEvents: true);
  }

  void updateSyncCursor(String? cursor) {
    if (cursor != null && cursor.isNotEmpty) {
      _syncCursor = cursor;
    }
  }

  /// Snapshot every ticket currently on the board as previous-shift leftovers.
  /// Reassigns [state] so cards rebuild with Clear footers.
  void markCurrentOrdersStale() {
    final List<Order>? orders = state.value;
    if (orders == null) {
      _staleOrderIds = <String>{};
      return;
    }
    _staleOrderIds = orders.map((Order order) => order.id).toSet();
    _publishStaleIds();
    state = AsyncData<List<Order>>(List<Order>.of(orders));
  }

  /// Client-only dismiss of one leftover ticket. Live (non-stale) ids are a no-op.
  void dismissStaleOrder(String orderId) {
    if (!isStaleLeftover(orderId)) {
      return;
    }
    final List<Order>? orders = state.value;
    if (orders == null) {
      return;
    }
    _staleOrderIds.remove(orderId);
    _publishStaleIds();
    state = AsyncData<List<Order>>(
      orders.where((Order order) => order.id != orderId).toList(),
    );
  }

  /// Client-only wipe of the on-screen list. Does not emit order events or
  /// change [syncCursor] — shift notices are not sync state.
  void clearStationOrders() {
    if (state.value == null) {
      return;
    }
    _staleOrderIds = <String>{};
    _publishStaleIds();
    state = const AsyncData<List<Order>>(<Order>[]);
  }

  Future<void> applySyncResult(SyncResult result) async {
    if (result.requiresFullReload) {
      await refresh();
      return;
    }
    for (final SyncEvent event in result.events) {
      replaceOrder(event.order);
      updateSyncCursor(event.cursor);
    }
    updateSyncCursor(result.nextCursor);
  }

  Future<void> _runOrderAction({
    required String orderId,
    required OrderStatus allowedFrom,
    required Future<OrderActionResult> Function(
      AuthSession session,
      String deviceId,
      Order order,
      String idempotencyKey,
    )
    call,
  }) async {
    final List<Order>? orders = state.value;
    if (orders == null) {
      return;
    }

    final Order? order = _find(orders, orderId);
    if (order == null || order.status != allowedFrom) {
      return;
    }

    final AuthSession? session = _session;
    final String? deviceId = _deviceId;
    final String key = _uuid.v4();

    if (session == null || deviceId == null) {
      _replaceLocal(
        order.copyWith(
          status: switch (allowedFrom) {
            OrderStatus.newOrder => OrderStatus.cooking,
            OrderStatus.cooking => OrderStatus.completed,
            OrderStatus.completed => OrderStatus.cooking,
            OrderStatus.cancelled => order.status,
          },
          version: order.version + 1,
          updatedAt: DateTime.now().toUtc(),
          clearCompletedAt: allowedFrom == OrderStatus.completed,
          completedAt: allowedFrom == OrderStatus.cooking
              ? DateTime.now().toUtc()
              : order.completedAt,
        ),
      );
      return;
    }

    try {
      final OrderActionResult result = await call(
        session,
        deviceId,
        order,
        key,
      );
      if (result.fullOrder != null) {
        _replaceLocal(result.fullOrder!);
      } else {
        _replaceLocal(
          order.copyWith(
            status: result.status,
            version: result.version,
            updatedAt: result.updatedAt,
            completedAt: result.completedAt,
            clearCompletedAt: result.completedAt == null &&
                result.status != OrderStatus.completed,
          ),
        );
      }
      _lastActionMessage = null;
    } on KdsApiError catch (error) {
      await _handleMutationError(error);
    }
  }

  Future<void> _handleMutationError(KdsApiError error) async {
    if (error.isVersionConflict && error.order != null) {
      _replaceLocal(error.order!, emitEvents: true);
      _lastActionMessage = 'Order updated elsewhere';
      return;
    }
    if (error.isInvalidTransition) {
      final Object? current = error.details['currentStatus'];
      if (current is String) {
        final List<Order>? orders = state.value;
        final Order? local = orders == null
            ? null
            : _find(orders, error.order?.id ?? '');
        if (error.order != null) {
          _replaceLocal(error.order!, emitEvents: true);
        } else if (local != null) {
          try {
            _replaceLocal(
              local.copyWith(status: OrderStatus.values.byName(current)),
              emitEvents: true,
            );
          } on ArgumentError {
            await refresh();
          }
        } else {
          await refresh();
        }
      } else if (error.order != null) {
        _replaceLocal(error.order!, emitEvents: true);
      }
      _lastActionMessage = error.message;
      return;
    }
    _lastActionMessage = error.message;
  }

  void _applyItemPatch(ItemPatchResult result) {
    if (result.fullOrder != null) {
      _replaceLocal(result.fullOrder!);
      return;
    }
    final List<Order>? orders = state.value;
    if (orders == null) {
      return;
    }
    final Order? order = _find(orders, result.orderId);
    if (order == null) {
      return;
    }
    _replaceLocal(
      order.copyWith(
        status: result.orderStatus,
        version: result.orderVersion,
        updatedAt: result.orderUpdatedAt,
        completedAt: result.orderCompletedAt,
        items: order.items.map((OrderItem item) {
          if (item.id != result.itemId) {
            return item;
          }
          return item.copyWith(
            isCompleted: result.isCompleted,
            isRemoved: result.isRemoved,
            isRemovedUnseen: result.isRemovedUnseen,
            isNew: result.isCompleted ? false : item.isNew,
          );
        }).toList(),
      ),
    );
  }

  void _replaceLocal(
    Order order, {
    bool insertIfMissing = false,
    bool emitEvents = false,
  }) {
    final List<Order> current = state.value ?? <Order>[];
    final int index = current.indexWhere((Order o) => o.id == order.id);
    if (index < 0) {
      if (insertIfMissing) {
        final Order stamped = stampCancelledAt(order);
        if (emitEvents) {
          _emitOrderEvents(null, stamped);
        }
        state = AsyncData<List<Order>>(<Order>[...current, stamped]);
      }
      return;
    }
    final Order previous = current[index];
    final Order stamped = stampCancelledAt(order, previous: previous);
    if (emitEvents) {
      _emitOrderEvents(previous, stamped);
    }
    final List<Order> next = List<Order>.of(current);
    next[index] = stamped;
    state = AsyncData<List<Order>>(next);
  }

  void _emitOrderEvents(Order? previous, Order next) {
    final StreamController<KdsOrderEvent> controller = ref.read(
      orderEventsControllerProvider,
    );
    for (final KdsOrderEvent event in diffOrderEvents(previous, next)) {
      controller.add(event);
    }
  }

  Order? _find(List<Order> orders, String orderId) {
    for (final Order order in orders) {
      if (order.id == orderId) {
        return order;
      }
    }
    return null;
  }

  OrderItem? _findItem(Order order, String itemId) {
    for (final OrderItem item in order.items) {
      if (item.id == itemId) {
        return item;
      }
    }
    return null;
  }
}

final AsyncNotifierProvider<OrderController, List<Order>>
orderControllerProvider =
    AsyncNotifierProvider<OrderController, List<Order>>(OrderController.new);

/// Broadcast bus for chef-facing order diffs. Lives next to
/// [orderControllerProvider] so the notifier can emit without importing
/// providers.dart (same circular-import pattern as urgency settings).
final Provider<StreamController<KdsOrderEvent>> orderEventsControllerProvider =
    Provider<StreamController<KdsOrderEvent>>((Ref ref) {
      final StreamController<KdsOrderEvent> controller =
          StreamController<KdsOrderEvent>.broadcast(sync: true);
      ref.onDispose(controller.close);
      return controller;
    });

final StreamProvider<KdsOrderEvent> orderEventsProvider =
    StreamProvider<KdsOrderEvent>((Ref ref) {
      return ref.watch(orderEventsControllerProvider).stream;
    });

/// IDs snapshotted at [OrderController.markCurrentOrdersStale]. Cards watch
/// this instead of the notifier so isolated widget tests need not load orders.
final StateProvider<Set<String>> staleLeftoverOrderIdsProvider =
    StateProvider<Set<String>>((Ref ref) => <String>{});
