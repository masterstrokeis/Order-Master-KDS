import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../constants/kds_config.dart';

/// Console logger for KDS REST traffic. No-ops when [KdsConfig.enableApiLogging]
/// is false (production default).
abstract final class KdsApiLogger {
  static const Set<String> _secretKeys = <String>{
    'pin',
    'accessToken',
    'refreshToken',
  };

  static void request({
    required String method,
    required Uri uri,
    Map<String, dynamic>? body,
  }) {
    if (!KdsConfig.enableApiLogging) {
      return;
    }
    debugPrint('[KDS API] → $method $uri');
    if (body != null) {
      debugPrint('[KDS API]   body: ${_encode(body)}');
    }
  }

  static void response({
    required int statusCode,
    required Object? body,
  }) {
    if (!KdsConfig.enableApiLogging) {
      return;
    }
    debugPrint('[KDS API] ← $statusCode ${_encode(body)}');
  }

  static void refreshRetry() {
    if (!KdsConfig.enableApiLogging) {
      return;
    }
    debugPrint('[KDS API] 401 → refreshing and retrying once');
  }

  static void websocket(String message) {
    if (!KdsConfig.enableApiLogging) {
      return;
    }
    debugPrint('[KDS WS] $message');
  }

  static String _encode(Object? value) {
    try {
      return jsonEncode(_redact(value));
    } catch (_) {
      return value.toString();
    }
  }

  static Object? _redact(Object? value) {
    if (value is Map) {
      return <String, Object?>{
        for (final MapEntry<dynamic, dynamic> entry in value.entries)
          entry.key.toString(): _secretKeys.contains(entry.key.toString())
              ? '***'
              : _redact(entry.value),
      };
    }
    if (value is List) {
      return value.map(_redact).toList();
    }
    return value;
  }
}
