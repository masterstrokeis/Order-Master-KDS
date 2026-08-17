import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/models/auth_session.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/models/restaurant_model.dart';
import 'package:order_master_kds/models/staff_model.dart';
import 'package:order_master_kds/models/websocket_config.dart';
import 'package:order_master_kds/services/kds_websocket_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _FakeWebSocketSink extends Fake implements WebSocketSink {
  _FakeWebSocketSink(this._onAdd);

  final void Function(Object? data) _onAdd;

  @override
  void add(Object? data) => _onAdd(data);

  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) async {}
}

class _FakeWebSocketChannel extends Fake implements WebSocketChannel {
  _FakeWebSocketChannel({
    required this.incoming,
    required void Function(Object? data) onAdd,
  }) : _sink = _FakeWebSocketSink(onAdd);

  final StreamController<dynamic> incoming;
  final _FakeWebSocketSink _sink;

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  Future<void> get ready => Future<void>.value();
}

void main() {
  late List<StreamController<dynamic>> incomings;
  late List<Uri> uris;
  late List<Map<String, dynamic>> hellos;
  late KdsWebSocketService service;

  AuthSession session({String accessToken = 'token'}) {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: 'refresh',
      expiresAt: DateTime.utc(2030, 1, 1),
      staff: const Staff(id: 'staff_1', name: 'John', initials: 'JO'),
      restaurant: const Restaurant(id: 'rest_1', name: 'Order Master'),
      outlet: const Outlet(id: 'outlet_default', name: 'Main'),
    );
  }

  Map<String, dynamic> orderJson() {
    return <String, dynamic>{
      'id': 'ord_1:station_grill',
      'displayNumber': 'A1',
      'stationId': 'station_grill',
      'createdAt': '2026-08-15T11:00:00Z',
      'type': 'dineIn',
      'status': 'newOrder',
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'item_1:station_grill',
          'productId': 'prod_1',
          'nameSnapshot': 'Burger',
          'quantity': 1,
        },
      ],
    };
  }

  Future<void> pumpMicrotasks() => Future<void>.delayed(Duration.zero);

  setUp(() {
    incomings = <StreamController<dynamic>>[];
    uris = <Uri>[];
    hellos = <Map<String, dynamic>>[];
    service = KdsWebSocketService(
      useMockBackend: false,
      channelFactory: (Uri uri) {
        uris.add(uri);
        final StreamController<dynamic> incoming = StreamController<dynamic>();
        incomings.add(incoming);
        return _FakeWebSocketChannel(
          incoming: incoming,
          onAdd: (Object? data) {
            final Object decoded = jsonDecode(data! as String);
            if (decoded is Map<String, dynamic> &&
                decoded['type'] == 'client.hello') {
              hellos.add(decoded);
            }
          },
        );
      },
    );
    addTearDown(service.dispose);
    addTearDown(() async {
      for (final StreamController<dynamic> incoming in incomings) {
        if (!incoming.isClosed) {
          await incoming.close();
        }
      }
    });
  });

  Future<void> connect({
    String? lastCursor = 'cursor_42',
    int reconnectMinDelayMs = 1,
  }) {
    return service.connect(
      config: WebsocketConfig(
        url: 'ws://localhost:5012/api/v1/kds/ws',
        heartbeatIntervalSeconds: 20,
        reconnectMinDelayMs: reconnectMinDelayMs,
        reconnectMaxDelayMs: reconnectMinDelayMs,
      ),
      session: session(),
      deviceId: 'device-1',
      stationId: 'station_grill',
      lastCursor: lastCursor,
    );
  }

  test('server.hello cursor is not sent on the next client.hello', () async {
    service.resolveAppliedCursor = () => 'cursor_42';
    await connect();
    expect(hellos, hasLength(1));
    expect(hellos.single['lastCursor'], 'cursor_42');

    incomings.single.add(
      jsonEncode(<String, dynamic>{
        'type': 'server.hello',
        'syncRequired': true,
        'cursor': 'cursor_50',
      }),
    );
    await pumpMicrotasks();

    await incomings.single.close();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(hellos, hasLength(2));
    expect(hellos.last['lastCursor'], 'cursor_42');
  });

  test('client.hello uses resolveAppliedCursor after it advances', () async {
    String? applied = 'cursor_42';
    service.resolveAppliedCursor = () => applied;
    await connect();

    applied = 'cursor_50';
    await incomings.single.close();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(hellos, hasLength(2));
    expect(hellos.last['lastCursor'], 'cursor_50');
  });

  test('shift.opened and shift.closed fire onShiftEvent', () async {
    final List<(ShiftEventKind, String)> received =
        <(ShiftEventKind, String)>[];
    service.onShiftEvent = (ShiftEventKind kind, String message) {
      received.add((kind, message));
    };

    await connect();
    incomings.single.add(
      jsonEncode(<String, dynamic>{
        'type': 'shift.opened',
        'eventId': 'shift_f6e5d4c3b2a1',
        'payload': <String, dynamic>{
          'openedShift': '20260816',
          'message': '  New business day has started  ',
        },
      }),
    );
    incomings.single.add(
      jsonEncode(<String, dynamic>{
        'type': 'shift.closed',
        'eventId': 'shift_a1b2c3d4e5f6',
        'payload': <String, dynamic>{
          'closedShift': '20260815',
          'message': 'Business day has been closed',
        },
      }),
    );
    await pumpMicrotasks();

    expect(received, <(ShiftEventKind, String)>[
      (ShiftEventKind.opened, 'New business day has started'),
      (ShiftEventKind.closed, 'Business day has been closed'),
    ]);
  });

  test('shift events drop when payload message is missing or blank', () async {
    int calls = 0;
    service.onShiftEvent = (ShiftEventKind kind, String message) {
      calls++;
    };

    await connect();
    incomings.single.add(
      jsonEncode(<String, dynamic>{'type': 'shift.opened'}),
    );
    incomings.single.add(
      jsonEncode(<String, dynamic>{
        'type': 'shift.closed',
        'payload': 'not-a-map',
      }),
    );
    incomings.single.add(
      jsonEncode(<String, dynamic>{
        'type': 'shift.opened',
        'payload': <String, dynamic>{'openedShift': '20260816'},
      }),
    );
    incomings.single.add(
      jsonEncode(<String, dynamic>{
        'type': 'shift.closed',
        'payload': <String, dynamic>{'message': 12},
      }),
    );
    incomings.single.add(
      jsonEncode(<String, dynamic>{
        'type': 'shift.opened',
        'payload': <String, dynamic>{'message': '   '},
      }),
    );
    await pumpMicrotasks();

    expect(calls, 0);
  });

  test('order.created still fires onOrderEvent', () async {
    Order? received;
    String? receivedCursor;
    service.onOrderEvent = (Order order, String? cursor) {
      received = order;
      receivedCursor = cursor;
    };

    await connect();
    incomings.single.add(
      jsonEncode(<String, dynamic>{
        'type': 'order.created',
        'cursor': 'cursor_43',
        'payload': <String, dynamic>{'order': orderJson()},
      }),
    );
    await pumpMicrotasks();

    expect(received, isNotNull);
    expect(received!.id, 'ord_1:station_grill');
    expect(receivedCursor, 'cursor_43');
  });

  test('order.created with DELIVERY type reaches onOrderEvent', () async {
    Order? received;
    service.onOrderEvent = (Order order, String? cursor) {
      received = order;
    };

    await connect();
    incomings.single.add(
      jsonEncode(<String, dynamic>{
        'type': 'order.created',
        'cursor': 'cursor_000002',
        'payload': <String, dynamic>{
          'order': <String, dynamic>{
            ...orderJson(),
            'id': 'ord_2:station_cash',
            'type': 'DELIVERY',
            'tableNumber': null,
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'item_2:station_cash',
                'productId': 'prod_67',
                'nameSnapshot': 'CHOCOLATE FALOODA-FALOODA',
                'quantity': 1.000,
                'sortOrder': 1,
              },
            ],
          },
        },
      }),
    );
    await pumpMicrotasks();

    expect(received, isNotNull);
    expect(received!.type, OrderType.delivery);
    expect(received!.id, 'ord_2:station_cash');
  });

  test('reconnect URI uses resolveSession access token', () async {
    AuthSession current = session(accessToken: 'old-token');
    service.resolveSession = () => current;
    await connect();
    expect(uris.single.queryParameters['access_token'], 'old-token');

    current = session(accessToken: 'new-token');
    await incomings.single.close();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(uris, hasLength(2));
    expect(uris.last.queryParameters['access_token'], 'new-token');
  });
}
