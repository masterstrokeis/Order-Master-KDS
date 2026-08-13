/// Staging / environment constants for KDS backend integration.
///
/// Override at build time, e.g.:
/// `--dart-define=KDS_BASE_URL=http://10.0.2.2:5012`
/// `--dart-define=KDS_USE_MOCK=false`
/// `--dart-define=KDS_API_LOGGING=true`
abstract final class KdsConfig {
  static const String baseUrl = String.fromEnvironment(
    'KDS_BASE_URL',
    defaultValue: 'http://192.168.1.9:5012',
  );

  /// When true, auth/orders use in-process mocks (no network).
  /// Set false to hit staging ([baseUrl]).
  static const bool useMockBackend = bool.fromEnvironment(
    'KDS_USE_MOCK',
    defaultValue: false,
  );

  /// When true, log every KDS REST request/response to the console.
  /// Keep false in production builds.
  static const bool enableApiLogging = bool.fromEnvironment(
    'KDS_API_LOGGING',
    defaultValue: true,
  );

  static const String apiPrefix = '/api/v1/kds';
}
