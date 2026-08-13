import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants/kds_config.dart';
import '../core/utils/kds_api_logger.dart';
import '../models/auth_session.dart';
import '../models/order_model.dart';
import '../models/websocket_config.dart';

typedef OrderEventHandler = void Function(Order order, String? cursor);
typedef SyncRequiredHandler = void Function();

/// WebSocket client: hello, ping/pong, order.created/updated, reconnect backoff.
class KdsWebSocketService {
  KdsWebSocketService({
    bool? useMockBackend,
    WebSocketChannel Function(Uri uri)? channelFactory,
  }) : _useMockBackend = useMockBackend ?? KdsConfig.useMockBackend,
       _channelFactory = channelFactory;

  final bool _useMockBackend;
  final WebSocketChannel Function(Uri uri)? _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _watchdogTimer;
  DateTime? _lastMessageAt;
  int _reconnectAttempt = 0;
  bool _disposed = false;
  bool _intentionalClose = false;

  WebsocketConfig? _config;
  AuthSession? _session;
  String? _deviceId;
  String? _stationId;
  String? _lastCursor;

  OrderEventHandler? onOrderEvent;
  SyncRequiredHandler? onSyncRequired;
  void Function(Object error)? onError;

  bool get isConnected => _channel != null;

  Future<void> connect({
    required WebsocketConfig config,
    required AuthSession session,
    required String deviceId,
    required String stationId,
    String? lastCursor,
  }) async {
    _config = config;
    _session = session;
    _deviceId = deviceId;
    _stationId = stationId;
    _lastCursor = lastCursor;
    _intentionalClose = false;

    if (_useMockBackend) {
      return;
    }

    await _open();
  }

  Future<void> updateStation({
    required String stationId,
    String? lastCursor,
  }) async {
    _stationId = stationId;
    if (lastCursor != null) {
      _lastCursor = lastCursor;
    }
    if (_useMockBackend || _config == null || _session == null || _deviceId == null) {
      return;
    }
    await disconnect(intentional: true);
    _intentionalClose = false;
    await _open();
  }

  Future<void> disconnect({bool intentional = true}) async {
    _intentionalClose = intentional;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cancelWatchdog();
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    disconnect(intentional: true);
  }

  Future<void> _open() async {
    if (_disposed || _useMockBackend) {
      return;
    }
    final WebsocketConfig config = _config!;
    final AuthSession session = _session!;
    final String deviceId = _deviceId!;
    final String stationId = _stationId!;

    final Uri uri = Uri.parse(config.url).replace(
      queryParameters: <String, String>{
        'restaurantId': session.restaurant.id,
        'outletId': session.outlet.id,
        'stationId': stationId,
        'deviceId': deviceId,
        'access_token': session.accessToken,
      },
    );

    KdsApiLogger.websocket('→ connecting $uri'.replaceAll(
      session.accessToken,
      '***',
    ));

    try {
      final WebSocketChannel channel = _channelFactory != null
          ? _channelFactory(uri)
          : WebSocketChannel.connect(uri);
      // Await ready so connection failures are caught here instead of as
      // unhandled WebSocketChannelExceptions. Timeout so an unreachable
      // host/port fails fast into the catch → reconnect loop.
      await channel.ready.timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException('WS connect timed out'),
      );
      if (_disposed || _intentionalClose) {
        await channel.sink.close();
        return;
      }

      _channel = channel;
      _reconnectAttempt = 0;
      _lastMessageAt = DateTime.now();
      _startWatchdog();
      KdsApiLogger.websocket('← connected station=$stationId');

      _subscription = channel.stream.listen(
        _onMessage,
        onError: (Object error) {
          KdsApiLogger.websocket('stream error: $error');
          onError?.call(error);
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );

      channel.sink.add(
        jsonEncode(<String, dynamic>{
          'type': 'client.hello',
          'messageId': 'hello_${DateTime.now().millisecondsSinceEpoch}',
          if (_lastCursor != null) 'lastCursor': _lastCursor,
        }),
      );
    } catch (error) {
      KdsApiLogger.websocket('connect failed: $error');
      onError?.call(error);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    _lastMessageAt = DateTime.now();

    final Object? decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map<String, dynamic>) {
      KdsApiLogger.websocket('← non-map message: $raw');
      return;
    }

    final String? type = decoded['type'] as String?;
    KdsApiLogger.websocket('← type=${type ?? 'null'}');

    switch (type) {
      case 'server.hello':
        final bool syncRequired = decoded['syncRequired'] as bool? ?? false;
        final String? cursor = decoded['cursor'] as String?;
        if (cursor != null) {
          _lastCursor = cursor;
        }
        if (syncRequired) {
          onSyncRequired?.call();
        }
        break;
      case 'ping':
        final String? messageId = decoded['messageId'] as String?;
        _channel?.sink.add(
          jsonEncode(<String, dynamic>{
            'type': 'pong',
            'messageId': messageId,
            'clientTime': DateTime.now().toUtc().toIso8601String(),
          }),
        );
        break;
      case 'order.created':
      case 'order.updated':
        final Map<String, dynamic>? payload =
            decoded['payload'] as Map<String, dynamic>?;
        final Map<String, dynamic>? orderJson =
            payload?['order'] as Map<String, dynamic>?;
        if (orderJson == null) {
          KdsApiLogger.websocket(
            'order event received but payload.order missing/unparseable: $raw',
          );
          return;
        }
        try {
          final String? cursor = decoded['cursor'] as String?;
          if (cursor != null) {
            _lastCursor = cursor;
          }
          onOrderEvent?.call(Order.fromJson(orderJson), cursor);
        } catch (error) {
          KdsApiLogger.websocket(
            'order event received but payload.order missing/unparseable: $raw',
          );
          KdsApiLogger.websocket('parse error: $error');
        }
        break;
      default:
        KdsApiLogger.websocket('← unrecognized type=${type ?? 'null'}: $raw');
        break;
    }
  }

  void _startWatchdog() {
    _cancelWatchdog();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkWatchdog();
    });
  }

  void _cancelWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  void _checkWatchdog() {
    final DateTime? lastMessageAt = _lastMessageAt;
    if (lastMessageAt == null || _channel == null || _disposed) {
      return;
    }

    final int heartbeatSeconds = _config?.heartbeatIntervalSeconds ?? 0;
    final Duration staleAfter = heartbeatSeconds > 0
        ? Duration(seconds: heartbeatSeconds * 2)
        : const Duration(seconds: 45);

    final Duration silence = DateTime.now().difference(lastMessageAt);
    if (silence <= staleAfter) {
      return;
    }

    KdsApiLogger.websocket(
      'watchdog: no message for ${silence.inSeconds}s '
      '(limit ${staleAfter.inSeconds}s) → reconnecting',
    );
    _cancelWatchdog();
    // Force-close as a dead connection, then reconnect with backoff.
    unawaited(_forceCloseDeadConnection());
  }

  Future<void> _forceCloseDeadConnection() async {
    // intentional: true so stream onDone does not also schedule reconnect.
    await disconnect(intentional: true);
    _intentionalClose = false;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _intentionalClose || _useMockBackend) {
      return;
    }
    _cancelWatchdog();
    _channel = null;
    _subscription = null;
    _reconnectTimer?.cancel();

    final WebsocketConfig config = _config!;
    final int delayMs = _backoffMs(
      attempt: _reconnectAttempt,
      minMs: config.reconnectMinDelayMs,
      maxMs: config.reconnectMaxDelayMs,
    );
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      _open();
    });
  }

  int _backoffMs({
    required int attempt,
    required int minMs,
    required int maxMs,
  }) {
    final int exp = minMs * (1 << attempt.clamp(0, 5));
    return exp.clamp(minMs, maxMs);
  }
}
