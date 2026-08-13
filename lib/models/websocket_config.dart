import '../core/constants/kds_config.dart';

class WebsocketConfig {
  const WebsocketConfig({
    required this.url,
    required this.heartbeatIntervalSeconds,
    this.reconnectMinDelayMs = 500,
    this.reconnectMaxDelayMs = 10000,
  });

  factory WebsocketConfig.fromJson(Map<String, dynamic> json) {
    // Heartbeat / reconnect come from bootstrap; URL always from KdsConfig.
    return WebsocketConfig(
      url: urlFromKdsConfig(),
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

  /// WebSocket endpoint derived from [KdsConfig.baseUrl] + `/api/v1/kds/ws`.
  /// Bootstrap `websocket.url` is intentionally unused.
  static String urlFromKdsConfig() {
    final Uri httpBase = Uri.parse(KdsConfig.baseUrl);
    final String scheme = httpBase.scheme == 'https' ? 'wss' : 'ws';
    final int? port = httpBase.hasPort ? httpBase.port : null;

    return Uri(
      scheme: scheme,
      host: httpBase.host,
      port: port,
      path: '${KdsConfig.apiPrefix}/ws',
    ).toString();
  }
}
