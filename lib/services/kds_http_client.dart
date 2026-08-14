import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../core/constants/kds_config.dart';
import '../core/utils/kds_api_logger.dart';
import '../models/kds_api_error.dart';
import '../models/order_model.dart';

/// Called when an authenticated request returns HTTP 401.
/// Return a fresh access token to retry once, or null to fail.
typedef KdsUnauthorizedHandler = Future<String?> Function();

/// Thin HTTP helper: attaches KDS headers and maps the standard error envelope.
class KdsHttpClient {
  KdsHttpClient({
    http.Client? client,
    Uuid? uuid,
    String? baseUrl,
    this.onUnauthorized,
  }) : _client = client ?? http.Client(),
       _uuid = uuid ?? const Uuid(),
       _baseUrl = baseUrl ?? KdsConfig.baseUrl;

  final http.Client _client;
  final Uuid _uuid;
  final String _baseUrl;

  String get baseUrl => _baseUrl;

  /// Optional silent refresh hook for authenticated 401s.
  final KdsUnauthorizedHandler? onUnauthorized;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$_baseUrl${KdsConfig.apiPrefix}$path').replace(
      queryParameters: query,
    );
  }

  Map<String, String> _headers({
    required bool authenticated,
    String? accessToken,
    String? deviceId,
    bool jsonBody = false,
  }) {
    final Map<String, String> headers = <String, String>{
      if (jsonBody) 'Content-Type': 'application/json',
    };
    if (authenticated) {
      if (accessToken == null || accessToken.isEmpty) {
        throw StateError('accessToken required for authenticated KDS calls');
      }
      if (deviceId == null || deviceId.isEmpty) {
        throw StateError('deviceId required for authenticated KDS calls');
      }
      headers['Authorization'] = 'Bearer $accessToken';
      headers['X-Device-Id'] = deviceId;
      headers['X-Request-Id'] = _uuid.v4();
    }
    return headers;
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    bool authenticated = false,
    String? accessToken,
    String? deviceId,
    Map<String, String>? query,
  }) {
    final Uri uri = _uri(path, query);
    return _send(
      method: 'POST',
      uri: uri,
      body: body,
      authenticated: authenticated,
      accessToken: accessToken,
      send: (String? token) {
        return _client.post(
          uri,
          headers: _headers(
            authenticated: authenticated,
            accessToken: token,
            deviceId: deviceId,
            jsonBody: true,
          ),
          body: jsonEncode(body),
        );
      },
    );
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    required String accessToken,
    required String deviceId,
    Map<String, String>? query,
  }) {
    final Uri uri = _uri(path, query);
    return _send(
      method: 'GET',
      uri: uri,
      authenticated: true,
      accessToken: accessToken,
      send: (String? token) {
        return _client.get(
          uri,
          headers: _headers(
            authenticated: true,
            accessToken: token,
            deviceId: deviceId,
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    required Map<String, dynamic> body,
    required String accessToken,
    required String deviceId,
    Map<String, String>? query,
  }) {
    final Uri uri = _uri(path, query);
    return _send(
      method: 'PUT',
      uri: uri,
      body: body,
      authenticated: true,
      accessToken: accessToken,
      send: (String? token) {
        return _client.put(
          uri,
          headers: _headers(
            authenticated: true,
            accessToken: token,
            deviceId: deviceId,
            jsonBody: true,
          ),
          body: jsonEncode(body),
        );
      },
    );
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, dynamic> body,
    required String accessToken,
    required String deviceId,
    Map<String, String>? query,
  }) {
    final Uri uri = _uri(path, query);
    return _send(
      method: 'PATCH',
      uri: uri,
      body: body,
      authenticated: true,
      accessToken: accessToken,
      send: (String? token) {
        return _client.patch(
          uri,
          headers: _headers(
            authenticated: true,
            accessToken: token,
            deviceId: deviceId,
            jsonBody: true,
          ),
          body: jsonEncode(body),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _send({
    required String method,
    required Uri uri,
    Map<String, dynamic>? body,
    required bool authenticated,
    required String? accessToken,
    required Future<http.Response> Function(String? accessToken) send,
  }) async {
    KdsApiLogger.request(method: method, uri: uri, body: body);

    http.Response response = await send(accessToken);
    try {
      final Map<String, dynamic> decoded = _decode(response);
      KdsApiLogger.response(statusCode: response.statusCode, body: decoded);
      return decoded;
    } on KdsApiError catch (error) {
      KdsApiLogger.response(
        statusCode: response.statusCode,
        body: response.body.isEmpty
            ? <String, dynamic>{
                'error': <String, dynamic>{
                  'code': error.code,
                  'message': error.message,
                },
              }
            : _tryDecodeBody(response.body),
      );

      if (!authenticated ||
          error.statusCode != 401 ||
          onUnauthorized == null) {
        rethrow;
      }

      KdsApiLogger.refreshRetry();
      final String? refreshedToken = await onUnauthorized!();
      if (refreshedToken == null || refreshedToken.isEmpty) {
        rethrow;
      }

      // Single retry with the new access token — no further refresh loops.
      KdsApiLogger.request(method: method, uri: uri, body: body);
      response = await send(refreshedToken);
      try {
        final Map<String, dynamic> decoded = _decode(response);
        KdsApiLogger.response(statusCode: response.statusCode, body: decoded);
        return decoded;
      } on KdsApiError catch (retryError) {
        KdsApiLogger.response(
          statusCode: response.statusCode,
          body: response.body.isEmpty
              ? <String, dynamic>{
                  'error': <String, dynamic>{
                    'code': retryError.code,
                    'message': retryError.message,
                  },
                }
              : _tryDecodeBody(response.body),
        );
        rethrow;
      }
    }
  }

  Object? _tryDecodeBody(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final Object? decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{'data': decoded};
    }

    if (decoded is Map<String, dynamic>) {
      throw KdsApiError.fromJson(decoded, statusCode: response.statusCode);
    }

    throw KdsApiError(
      statusCode: response.statusCode,
      code: 'HTTP_${response.statusCode}',
      message: response.body.isEmpty ? 'Request failed' : response.body,
    );
  }

  void close() => _client.close();
}

/// Action summary returned by start/complete/rollback (partial order).
class OrderActionResult {
  const OrderActionResult({
    required this.orderId,
    required this.status,
    required this.version,
    required this.updatedAt,
    this.completedAt,
    this.alreadyApplied = false,
    this.fullOrder,
  });

  factory OrderActionResult.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> order =
        json['order'] as Map<String, dynamic>? ?? json;
    final bool hasItems = order['items'] is List;
    return OrderActionResult(
      orderId: order['id'] as String,
      status: OrderStatus.values.byName(order['status'] as String),
      version: order['version'] as int,
      updatedAt: DateTime.parse(order['updatedAt'] as String),
      completedAt: order['completedAt'] == null
          ? null
          : DateTime.parse(order['completedAt'] as String),
      alreadyApplied: json['alreadyApplied'] as bool? ?? false,
      fullOrder: hasItems ? Order.fromJson(order) : null,
    );
  }

  final String orderId;
  final OrderStatus status;
  final int version;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final bool alreadyApplied;
  final Order? fullOrder;
}
