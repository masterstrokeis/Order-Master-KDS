import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/models/bootstrap_result.dart';
import 'package:order_master_kds/models/kds_api_error.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/models/orders_list_result.dart';
import 'package:order_master_kds/models/product_model.dart';
import 'package:order_master_kds/models/station_model.dart';
import 'package:order_master_kds/models/sync_result.dart';
import 'package:order_master_kds/models/websocket_config.dart';

void main() {
  group('OrderItem.fromJson', () {
    test('parses opaque item id and flags without constructing ids', () {
      final OrderItem item = OrderItem.fromJson(<String, dynamic>{
        'id': 'item_987:station_grill',
        'sourceItemId': 'item_42',
        'productId': 'prod_100',
        'nameSnapshot': 'Burger',
        'quantity': 1,
        'modifierText': 'Medium',
        'note': null,
        'isCompleted': false,
        'isNew': true,
        'isRemoved': false,
        'isRemovedUnseen': false,
        'sortOrder': 2,
      });

      expect(item.id, 'item_987:station_grill');
      expect(item.sourceItemId, 'item_42');
      expect(item.isNew, isTrue);
      expect(item.isRemoved, isFalse);
      expect(item.isRemovedUnseen, isFalse);
      expect(item.sortOrder, 2);
    });

    test('accepts quantity and sortOrder as doubles from JSON', () {
      final OrderItem item = OrderItem.fromJson(<String, dynamic>{
        'id': 'item_8:station_grills',
        'sourceItemId': 'item_103',
        'productId': 'prod_8',
        'nameSnapshot': 'FRENCH FRIES-FRIES',
        'quantity': 1.0,
        'sortOrder': 2.0,
      });

      expect(item.quantity, 1);
      expect(item.sortOrder, 2);
    });

    test('defaults missing flags and sourceItemId to id', () {
      final OrderItem item = OrderItem.fromJson(<String, dynamic>{
        'id': 'item_1:station_grill',
        'productId': 'prod_100',
        'nameSnapshot': 'Fries',
        'quantity': 2,
      });

      expect(item.sourceItemId, 'item_1:station_grill');
      expect(item.isCompleted, isFalse);
      expect(item.isNew, isFalse);
      expect(item.isRemoved, isFalse);
      expect(item.isRemovedUnseen, isFalse);
      expect(item.sortOrder, 0);
    });

    test('parses removed + unseen flags', () {
      final OrderItem item = OrderItem.fromJson(<String, dynamic>{
        'id': 'item_2:station_grill',
        'sourceItemId': 'item_9',
        'productId': 'prod_100',
        'nameSnapshot': 'Salad',
        'quantity': 1,
        'isRemoved': true,
        'isRemovedUnseen': true,
      });

      expect(item.isRemoved, isTrue);
      expect(item.isRemovedUnseen, isTrue);
    });
  });

  group('Order.fromJson', () {
    test('parses opaque order id, version, and cancelled status', () {
      final Order order = Order.fromJson(<String, dynamic>{
        'id': 'ord_12345:station_grill',
        'sourceOrderId': 'ord_12345',
        'displayNumber': 'A12',
        'kotNumber': 'A12',
        'restaurantId': 'rest_001',
        'outletId': 'outlet_main',
        'stationId': 'station_grill',
        'createdAt': '2026-08-08T11:55:00Z',
        'updatedAt': '2026-08-08T11:56:00Z',
        'completedAt': null,
        'type': 'dineIn',
        'status': 'cancelled',
        'tableNumber': '5',
        'customerName': null,
        'note': 'No onions',
        'version': 4,
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'item_987:station_grill',
            'sourceItemId': 'item_42',
            'productId': 'prod_100',
            'nameSnapshot': 'Burger',
            'quantity': 1,
            'sortOrder': 1,
            'isRemoved': true,
            'isRemovedUnseen': true,
          },
          <String, dynamic>{
            'id': 'item_988:station_grill',
            'sourceItemId': 'item_43',
            'productId': 'prod_101',
            'nameSnapshot': 'Fries',
            'quantity': 1,
            'sortOrder': 0,
            'isNew': true,
          },
        ],
      });

      expect(order.id, 'ord_12345:station_grill');
      expect(order.sourceOrderId, 'ord_12345');
      expect(order.kotNumber, 'A12');
      expect(order.version, 4);
      expect(order.status, OrderStatus.cancelled);
      expect(order.completedAt, isNull);
      // Items sorted by sortOrder from payload.
      expect(order.items.map((OrderItem i) => i.id).toList(), <String>[
        'item_988:station_grill',
        'item_987:station_grill',
      ]);
      expect(order.items.first.isNew, isTrue);
      expect(order.items.last.isRemovedUnseen, isTrue);
    });

    test('parses all order statuses from API enum names', () {
      for (final OrderStatus status in OrderStatus.values) {
        final Order order = Order.fromJson(<String, dynamic>{
          'id': 'ord_1:station_grill',
          'sourceOrderId': 'ord_1',
          'displayNumber': 'B1',
          'restaurantId': 'rest_001',
          'outletId': 'outlet_main',
          'stationId': 'station_grill',
          'createdAt': '2026-08-08T11:55:00Z',
          'updatedAt': '2026-08-08T11:55:00Z',
          'type': 'takeOut',
          'status': status.name,
          'version': 1,
          'items': <Map<String, dynamic>>[],
        });
        expect(order.status, status);
      }
    });
  });

  group('Station / Product.fromJson', () {
    test('parses isActive and stationIds', () {
      final Station station = Station.fromJson(<String, dynamic>{
        'id': 'station_grill',
        'name': 'Grill',
        'displayOrder': 1,
        'isActive': true,
      });
      expect(station.isActive, isTrue);

      final Product product = Product.fromJson(<String, dynamic>{
        'id': 'prod_100',
        'name': 'Burger',
        'categoryId': 'cat_5',
        'stationIds': <String>['station_grill', 'station_fry'],
        'isActive': false,
      });
      expect(product.stationIds, <String>['station_grill', 'station_fry']);
      expect(product.isActive, isFalse);
    });
  });

  group('OrdersListResult / BootstrapResult / SyncResult', () {
    test('parses orders list with syncCursor', () {
      final OrdersListResult result = OrdersListResult.fromJson(
        <String, dynamic>{
          'serverTime': '2026-08-08T12:00:00Z',
          'stationId': 'station_grill',
          'syncCursor': 'cursor_42',
          'orders': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'ord_12345:station_grill',
              'sourceOrderId': 'ord_12345',
              'displayNumber': 'A12',
              'restaurantId': 'rest_001',
              'outletId': 'outlet_main',
              'stationId': 'station_grill',
              'createdAt': '2026-08-08T11:55:00Z',
              'updatedAt': '2026-08-08T11:56:00Z',
              'type': 'dineIn',
              'status': 'newOrder',
              'version': 1,
              'items': <Map<String, dynamic>>[],
            },
          ],
        },
      );

      expect(result.syncCursor, 'cursor_42');
      expect(result.orders, hasLength(1));
      expect(result.orders.single.id, 'ord_12345:station_grill');
    });

    test('parses empty orders list with null syncCursor', () {
      final OrdersListResult result = OrdersListResult.fromJson(
        <String, dynamic>{
          'serverTime': '2026-08-08T12:00:00Z',
          'stationId': 'station_cash',
          'syncCursor': null,
          'orders': <Map<String, dynamic>>[],
        },
      );

      expect(result.syncCursor, isNull);
      expect(result.orders, isEmpty);
    });

    test('parses bootstrap websocket config and catalog', () {
      final BootstrapResult bootstrap = BootstrapResult.fromJson(
        <String, dynamic>{
          'serverTime': '2026-08-08T12:00:00Z',
          'restaurant': <String, dynamic>{
            'id': 'rest_001',
            'name': 'Order Master',
          },
          'outlet': <String, dynamic>{
            'id': 'outlet_main',
            'name': 'Main Restaurant',
          },
          'stations': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'station_grill',
              'name': 'Grill',
              'displayOrder': 1,
              'isActive': true,
            },
          ],
          'categories': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'cat_5',
              'name': 'Mains',
              'sortOrder': 1,
            },
          ],
          'products': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'prod_100',
              'name': 'Burger',
              'categoryId': 'cat_5',
              'stationIds': <String>['station_grill'],
              'isActive': true,
            },
          ],
          'websocket': <String, dynamic>{
            'url': 'ws://localhost:5088/api/v1/kds/ws',
            'heartbeatIntervalSeconds': 20,
            'reconnectMinDelayMs': 500,
            'reconnectMaxDelayMs': 10000,
          },
        },
      );

      expect(bootstrap.stations.single.id, 'station_grill');
      expect(bootstrap.products.single.stationIds, <String>['station_grill']);
      expect(bootstrap.websocket.heartbeatIntervalSeconds, 20);
      expect(bootstrap.websocket.url, contains('/api/v1/kds/ws'));
      // Bootstrap websocket.url is ignored; URL comes from KdsConfig.baseUrl.
      expect(bootstrap.websocket.url, isNot(contains('localhost')));
      expect(bootstrap.websocket.url, isNot(contains(':5088')));
    });

    test('parses sync events with full order replace payload', () {
      final SyncResult sync = SyncResult.fromJson(<String, dynamic>{
        'serverTime': '2026-08-08T12:05:00Z',
        'nextCursor': 'cursor_43',
        'requiresFullReload': false,
        'events': <Map<String, dynamic>>[
          <String, dynamic>{
            'eventId': 'evt_43',
            'type': 'order.updated',
            'occurredAt': '2026-08-08T12:04:50Z',
            'stationId': 'station_grill',
            'cursor': 'cursor_43',
            'payload': <String, dynamic>{
              'order': <String, dynamic>{
                'id': 'ord_12345:station_grill',
                'sourceOrderId': 'ord_12345',
                'displayNumber': 'A12',
                'restaurantId': 'rest_001',
                'outletId': 'outlet_main',
                'stationId': 'station_grill',
                'createdAt': '2026-08-08T11:55:00Z',
                'updatedAt': '2026-08-08T12:04:50Z',
                'type': 'dineIn',
                'status': 'cooking',
                'version': 5,
                'items': <Map<String, dynamic>>[],
              },
            },
          },
        ],
      });

      expect(sync.requiresFullReload, isFalse);
      expect(sync.nextCursor, 'cursor_43');
      expect(sync.events.single.type, 'order.updated');
      expect(sync.events.single.order.version, 5);
    });
  });

  group('KdsApiError.fromJson', () {
    test('parses VERSION_CONFLICT with full order body', () {
      final KdsApiError error = KdsApiError.fromJson(
        <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'VERSION_CONFLICT',
            'message': 'Order was updated by another device.',
            'details': <String, dynamic>{},
            'currentVersion': 5,
          },
          'order': <String, dynamic>{
            'id': 'ord_12345:station_grill',
            'sourceOrderId': 'ord_12345',
            'displayNumber': 'A12',
            'restaurantId': 'rest_001',
            'outletId': 'outlet_main',
            'stationId': 'station_grill',
            'createdAt': '2026-08-08T11:55:00Z',
            'updatedAt': '2026-08-08T12:02:00Z',
            'type': 'dineIn',
            'status': 'cooking',
            'version': 5,
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'item_987:station_grill',
                'sourceItemId': 'item_42',
                'productId': 'prod_100',
                'nameSnapshot': 'Burger',
                'quantity': 1,
              },
            ],
          },
        },
        statusCode: 409,
      );

      expect(error.isVersionConflict, isTrue);
      expect(error.currentVersion, 5);
      expect(error.order?.id, 'ord_12345:station_grill');
      expect(error.order?.version, 5);
      expect(error.order?.items, hasLength(1));
    });

    test('parses INVALID_TRANSITION without order body', () {
      final KdsApiError error = KdsApiError.fromJson(
        <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'INVALID_TRANSITION',
            'message': "Cannot complete order from status 'newOrder'.",
            'details': <String, dynamic>{'currentStatus': 'newOrder'},
          },
        },
        statusCode: 409,
      );

      expect(error.isInvalidTransition, isTrue);
      expect(error.details['currentStatus'], 'newOrder');
      expect(error.order, isNull);
    });
  });

  group('WebsocketConfig', () {
    test('builds url from KdsConfig and ignores bootstrap url', () {
      final WebsocketConfig config = WebsocketConfig.fromJson(
        <String, dynamic>{
          'url': 'ws://localhost:5088/api/v1/kds/ws',
          'heartbeatIntervalSeconds': 20,
        },
      );

      final Uri expected = Uri.parse(WebsocketConfig.urlFromKdsConfig());
      final Uri actual = Uri.parse(config.url);

      expect(actual.scheme, expected.scheme);
      expect(actual.host, expected.host);
      expect(actual.port, expected.port);
      expect(actual.path, '/api/v1/kds/ws');
      expect(config.url, isNot(contains(':5088')));
      expect(config.heartbeatIntervalSeconds, 20);
    });
  });
}
