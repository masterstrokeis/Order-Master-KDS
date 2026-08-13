import '../core/constants/kds_config.dart';
import '../models/auth_session.dart';
import '../models/kds_api_error.dart';
import '../models/restaurant_model.dart';
import '../models/staff_model.dart';
import 'kds_http_client.dart';
import 'session_store.dart';

class AuthService {
  AuthService({
    required SessionStore sessionStore,
    KdsHttpClient? httpClient,
    bool? useMockBackend,
  }) : _sessionStore = sessionStore,
       _http = httpClient ?? KdsHttpClient(),
       _useMockBackend = useMockBackend ?? KdsConfig.useMockBackend;

  final SessionStore _sessionStore;
  final KdsHttpClient _http;
  final bool _useMockBackend;

  Future<AuthSession?> loadPersistedSession() => _sessionStore.load();

  Future<AuthSession> login({
    required String pin,
    required String deviceId,
  }) async {
    if (_useMockBackend) {
      final AuthSession session = _mockLogin(pin: pin);
      await _sessionStore.save(session);
      return session;
    }

    final Map<String, dynamic> json = await _http.postJson(
      '/auth/login',
      body: <String, dynamic>{
        'pin': pin,
        'deviceId': deviceId,
      },
    );
    final AuthSession session = AuthSession.fromJson(json);
    await _sessionStore.save(session);
    return session;
  }

  Future<AuthSession> refresh({
    required String refreshToken,
    required String deviceId,
  }) async {
    final AuthSession? existing = await _sessionStore.load();
    if (existing == null) {
      throw const KdsApiError(
        code: 'UNAUTHORIZED',
        message: 'No session to refresh.',
      );
    }

    if (_useMockBackend) {
      final AuthSession refreshed = existing.copyWith(
        accessToken: 'mock-access-${DateTime.now().millisecondsSinceEpoch}',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 30)),
      );
      await _sessionStore.save(refreshed);
      return refreshed;
    }

    final Map<String, dynamic> json = await _http.postJson(
      '/auth/refresh',
      body: <String, dynamic>{
        'refreshToken': refreshToken,
        'deviceId': deviceId,
      },
    );

    final AuthSession refreshed = existing.copyWith(
      accessToken: json['accessToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
    await _sessionStore.save(refreshed);
    return refreshed;
  }

  Future<void> logout() => _sessionStore.clear();

  AuthSession _mockLogin({required String pin}) {
    // Mock: any PIN works except "000" → INVALID_PIN for tests.
    if (pin == '000') {
      throw const KdsApiError(
        statusCode: 401,
        code: 'INVALID_PIN',
        message: 'Invalid PIN.',
      );
    }

    return AuthSession(
      accessToken: 'mock-access-token',
      refreshToken: 'mock-refresh-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 30)),
      staff: const Staff(
        id: 'staff_1',
        name: 'John',
        initials: 'JO',
        roles: <String>['kds_operator'],
      ),
      restaurant: const Restaurant(id: '123', name: 'Order Master'),
      outlet: const Outlet(id: '1', name: 'Main Counter'),
    );
  }
}
