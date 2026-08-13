import '../core/constants/kds_config.dart';
import '../models/auth_session.dart';
import '../models/bootstrap_result.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../models/orders_list_result.dart';
import '../models/product_category_model.dart';
import '../models/product_model.dart';
import '../models/station_model.dart';
import '../models/sync_result.dart';
import '../models/websocket_config.dart';
import 'kds_http_client.dart';
import 'mock_orders_service.dart';

class ItemPatchResult {
  const ItemPatchResult({
    required this.itemId,
    required this.isCompleted,
    required this.isRemoved,
    required this.isRemovedUnseen,
    required this.orderId,
    required this.orderStatus,
    required this.orderVersion,
    required this.orderUpdatedAt,
    this.orderCompletedAt,
    this.fullOrder,
  });

  factory ItemPatchResult.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> item =
        json['item'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final Map<String, dynamic> order =
        json['order'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final bool hasItems = order['items'] is List;
    return ItemPatchResult(
      itemId: item['id'] as String,
      isCompleted: item['isCompleted'] as bool? ?? false,
      isRemoved: item['isRemoved'] as bool? ?? false,
      isRemovedUnseen: item['isRemovedUnseen'] as bool? ?? false,
      orderId: order['id'] as String,
      orderStatus: OrderStatus.values.byName(order['status'] as String),
      orderVersion: order['version'] as int,
      orderUpdatedAt: DateTime.parse(order['updatedAt'] as String),
      orderCompletedAt: order['completedAt'] == null
          ? null
          : DateTime.parse(order['completedAt'] as String),
      fullOrder: hasItems ? Order.fromJson(order) : null,
    );
  }

  final String itemId;
  final bool isCompleted;
  final bool isRemoved;
  final bool isRemovedUnseen;
  final String orderId;
  final OrderStatus orderStatus;
  final int orderVersion;
  final DateTime orderUpdatedAt;
  final DateTime? orderCompletedAt;
  final Order? fullOrder;
}

class KdsApiService {
  KdsApiService({
    KdsHttpClient? httpClient,
    MockOrdersService? mockOrdersService,
    bool? useMockBackend,
  }) : _http = httpClient ?? KdsHttpClient(),
       _mock = mockOrdersService ?? const MockOrdersService(),
       _useMockBackend = useMockBackend ?? KdsConfig.useMockBackend;

  final KdsHttpClient _http;
  final MockOrdersService _mock;
  final bool _useMockBackend;

  BootstrapResult? _mockBootstrap;
  String _mockCursor = 'cursor_mock_1';

  Future<BootstrapResult> bootstrap({
    required AuthSession session,
    required String deviceId,
  }) async {
    if (_useMockBackend) {
      return _mockBootstrap ??= _buildMockBootstrap(session);
    }

    return BootstrapResult.fromJson(
      await _http.getJson(
        '/bootstrap',
        accessToken: session.accessToken,
        deviceId: deviceId,
        query: <String, String>{
          'restaurantId': session.restaurant.id,
          'outletId': session.outlet.id,
        },
      ),
    );
  }

  Future<void> setDeviceStation({
    required AuthSession session,
    required String deviceId,
    required String stationId,
  }) async {
    if (_useMockBackend) {
      return;
    }

    await _http.putJson(
      '/devices/me/station',
      accessToken: session.accessToken,
      deviceId: deviceId,
      body: <String, dynamic>{'stationId': stationId},
    );
  }

  Future<OrdersListResult> listOrders({
    required AuthSession session,
    required String deviceId,
    required String stationId,
    required String status,
  }) async {
    if (_useMockBackend) {
      final List<Order> all = await _mock.fetchOrders();
      final List<Order> filtered = all.where((Order order) {
        if (order.stationId != stationId) {
          return false;
        }
        if (status == 'completed') {
          return order.status == OrderStatus.completed;
        }
        return order.status != OrderStatus.completed;
      }).toList();

      return OrdersListResult(
        serverTime: DateTime.now().toUtc(),
        stationId: stationId,
        syncCursor: _mockCursor,
        orders: filtered,
      );
    }

    return OrdersListResult.fromJson(
      await _http.getJson(
        '/orders',
        accessToken: session.accessToken,
        deviceId: deviceId,
        query: <String, String>{
          'restaurantId': session.restaurant.id,
          'outletId': session.outlet.id,
          'stationId': stationId,
          'status': status,
        },
      ),
    );
  }

  Future<OrderActionResult> startOrder({
    required AuthSession session,
    required String deviceId,
    required Order order,
    required String idempotencyKey,
  }) {
    return _orderAction(
      session: session,
      deviceId: deviceId,
      order: order,
      idempotencyKey: idempotencyKey,
      pathSuffix: 'start',
      mockNextStatus: OrderStatus.cooking,
    );
  }

  Future<OrderActionResult> completeOrder({
    required AuthSession session,
    required String deviceId,
    required Order order,
    required String idempotencyKey,
  }) {
    return _orderAction(
      session: session,
      deviceId: deviceId,
      order: order,
      idempotencyKey: idempotencyKey,
      pathSuffix: 'complete',
      mockNextStatus: OrderStatus.completed,
    );
  }

  Future<OrderActionResult> rollbackOrder({
    required AuthSession session,
    required String deviceId,
    required Order order,
    required String idempotencyKey,
  }) {
    return _orderAction(
      session: session,
      deviceId: deviceId,
      order: order,
      idempotencyKey: idempotencyKey,
      pathSuffix: 'rollback',
      mockNextStatus: OrderStatus.cooking,
    );
  }

  Future<ItemPatchResult> patchItemCompleted({
    required AuthSession session,
    required String deviceId,
    required Order order,
    required String itemId,
    required bool isCompleted,
    required String idempotencyKey,
  }) async {
    if (_useMockBackend) {
      final DateTime now = DateTime.now().toUtc();
      final int nextVersion = order.version + 1;
      final Order full = order.copyWith(
        version: nextVersion,
        updatedAt: now,
        items: order.items.map((OrderItem item) {
          if (item.id != itemId) {
            return item;
          }
          return item.copyWith(
            isCompleted: isCompleted,
            isNew: isCompleted ? false : item.isNew,
          );
        }).toList(),
      );
      final OrderItem patched = full.items.firstWhere(
        (OrderItem i) => i.id == itemId,
      );
      return ItemPatchResult(
        itemId: itemId,
        isCompleted: patched.isCompleted,
        isRemoved: patched.isRemoved,
        isRemovedUnseen: patched.isRemovedUnseen,
        orderId: order.id,
        orderStatus: order.status,
        orderVersion: nextVersion,
        orderUpdatedAt: now,
        fullOrder: full,
      );
    }

    final String encodedOrderId = Uri.encodeComponent(order.id);
    final String encodedItemId = Uri.encodeComponent(itemId);
    return ItemPatchResult.fromJson(
      await _http.patchJson(
        '/orders/$encodedOrderId/items/$encodedItemId',
        accessToken: session.accessToken,
        deviceId: deviceId,
        query: <String, String>{'restaurantId': session.restaurant.id},
        body: <String, dynamic>{
          'stationId': order.stationId,
          'isCompleted': isCompleted,
          'staffId': session.staff.id,
          'deviceId': deviceId,
          'idempotencyKey': idempotencyKey,
          'expectedVersion': order.version,
        },
      ),
    );
  }

  Future<ItemPatchResult> acknowledgeRemovedItem({
    required AuthSession session,
    required String deviceId,
    required Order order,
    required String itemId,
    required String idempotencyKey,
  }) async {
    if (_useMockBackend) {
      final DateTime now = DateTime.now().toUtc();
      final int nextVersion = order.version + 1;
      final Order full = order.copyWith(
        version: nextVersion,
        updatedAt: now,
        items: order.items.map((OrderItem item) {
          if (item.id != itemId) {
            return item;
          }
          return item.copyWith(isRemovedUnseen: false);
        }).toList(),
      );
      final OrderItem patched = full.items.firstWhere(
        (OrderItem i) => i.id == itemId,
      );
      return ItemPatchResult(
        itemId: itemId,
        isCompleted: patched.isCompleted,
        isRemoved: patched.isRemoved,
        isRemovedUnseen: false,
        orderId: order.id,
        orderStatus: order.status,
        orderVersion: nextVersion,
        orderUpdatedAt: now,
        fullOrder: full,
      );
    }

    final String encodedOrderId = Uri.encodeComponent(order.id);
    final String encodedItemId = Uri.encodeComponent(itemId);
    return ItemPatchResult.fromJson(
      await _http.patchJson(
        '/orders/$encodedOrderId/items/$encodedItemId',
        accessToken: session.accessToken,
        deviceId: deviceId,
        query: <String, String>{'restaurantId': session.restaurant.id},
        body: <String, dynamic>{
          'stationId': order.stationId,
          'acknowledgeRemoved': true,
          'staffId': session.staff.id,
          'deviceId': deviceId,
          'idempotencyKey': idempotencyKey,
          'expectedVersion': order.version,
        },
      ),
    );
  }

  Future<SyncResult> syncSinceCursor({
    required AuthSession session,
    required String deviceId,
    required String stationId,
    required String cursor,
  }) async {
    if (_useMockBackend) {
      return SyncResult(
        serverTime: DateTime.now().toUtc(),
        events: const <SyncEvent>[],
        nextCursor: cursor,
        requiresFullReload: false,
      );
    }

    return SyncResult.fromJson(
      await _http.getJson(
        '/sync',
        accessToken: session.accessToken,
        deviceId: deviceId,
        query: <String, String>{
          'restaurantId': session.restaurant.id,
          'outletId': session.outlet.id,
          'stationId': stationId,
          'cursor': cursor,
        },
      ),
    );
  }

  Future<OrderActionResult> _orderAction({
    required AuthSession session,
    required String deviceId,
    required Order order,
    required String idempotencyKey,
    required String pathSuffix,
    required OrderStatus mockNextStatus,
  }) async {
    if (_useMockBackend) {
      final DateTime now = DateTime.now().toUtc();
      return OrderActionResult(
        orderId: order.id,
        status: mockNextStatus,
        version: order.version + 1,
        updatedAt: now,
        completedAt: mockNextStatus == OrderStatus.completed ? now : null,
        alreadyApplied: false,
      );
    }

    final String encodedOrderId = Uri.encodeComponent(order.id);
    return OrderActionResult.fromJson(
      await _http.postJson(
        '/orders/$encodedOrderId/$pathSuffix',
        authenticated: true,
        accessToken: session.accessToken,
        deviceId: deviceId,
        query: <String, String>{'restaurantId': session.restaurant.id},
        body: <String, dynamic>{
          'stationId': order.stationId,
          'staffId': session.staff.id,
          'deviceId': deviceId,
          'idempotencyKey': idempotencyKey,
          'expectedVersion': order.version,
          'reason': null,
        },
      ),
    );
  }

  BootstrapResult _buildMockBootstrap(AuthSession session) {
    final List<Station> stations = _mock.fetchStations();
    final List<ProductCategory> categories = _mock.fetchCategories();
    final List<Product> products = _mock.fetchProducts();
    return BootstrapResult(
      serverTime: DateTime.now().toUtc(),
      restaurant: session.restaurant,
      outlet: session.outlet,
      stations: stations,
      categories: categories,
      products: products
          .map(
            (Product p) => Product(
              id: p.id,
              name: p.name,
              categoryId: p.categoryId,
              stationIds: stations.map((Station s) => s.id).toList(),
              isActive: true,
            ),
          )
          .toList(),
      websocket: WebsocketConfig(
        url: WebsocketConfig.urlFromKdsConfig(),
        heartbeatIntervalSeconds: 20,
      ),
    );
  }
}
