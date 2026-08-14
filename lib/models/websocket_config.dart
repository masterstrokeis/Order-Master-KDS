import '../core/constants/kds_config.dart';

class WebsocketConfig {
  const WebsocketConfig({
    required this.url,
    required this.heartbeatIntervalSeconds,
    this.reconnectMinDelayMs = 500,
    this.reconnectMaxDelayMs = 10000,
  });

  factory WebsocketConfig.fromJson(
    Map<String, dynamic> json, {
    String? httpBaseUrl,
  }) {
    // Heartbeat / reconnect come from bootstrap; URL from the active HTTP base.
    return WebsocketConfig(
      url: urlFromHttpBase(httpBaseUrl ?? KdsConfig.baseUrl),
      heartbeatIntervalSeconds: (json['heartbeatIntervalSeconds'] as num)
          .toInt(),
      reconnectMinDelayMs:
          (json['reconnectMinDelayMs'] as num?)?.toInt() ?? 500,
      reconnectMaxDelayMs:
          (json['reconnectMaxDelayMs'] as num?)?.toInt() ?? 10000,
    );
  }

  final String url;
  final int heartbeatIntervalSeconds;
  final int reconnectMinDelayMs;
  final int reconnectMaxDelayMs;

  /// WebSocket endpoint derived from the HTTP base URL + `/api/v1/kds/ws`.
  /// Bootstrap `websocket.url` is intentionally unused.
  static String urlFromHttpBase(String httpBaseUrl) {
    final Uri httpBase = Uri.parse(httpBaseUrl);
    final String scheme = httpBase.scheme == 'https' ? 'wss' : 'ws';
    final int? port = httpBase.hasPort ? httpBase.port : null;

    return Uri(
      scheme: scheme,
      host: httpBase.host,
      port: port,
      path: '${KdsConfig.apiPrefix}/ws',
    ).toString();
  }

  static String urlFromKdsConfig() => urlFromHttpBase(KdsConfig.baseUrl);
}
