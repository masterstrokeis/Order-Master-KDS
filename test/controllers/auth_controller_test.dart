import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/auth_controller.dart';
import 'package:order_master_kds/models/auth_session.dart';
import 'package:order_master_kds/models/kds_api_error.dart';
import 'package:order_master_kds/models/restaurant_model.dart';
import 'package:order_master_kds/models/server_config.dart';
import 'package:order_master_kds/models/staff_model.dart';
import 'package:order_master_kds/services/auth_service.dart';
import 'package:order_master_kds/services/device_identity_service.dart';
import 'package:order_master_kds/services/server_config_service.dart';
import 'package:order_master_kds/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingRefreshAuthService extends AuthService {
  _FailingRefreshAuthService({required super.sessionStore})
    : super(useMockBackend: true);

  int refreshCalls = 0;

  @override
  Future<AuthSession> refresh({
    required String refreshToken,
    required String deviceId,
  }) async {
    refreshCalls++;
    throw const KdsApiError(
      statusCode: 401,
      code: 'UNAUTHORIZED',
      message: 'Refresh token expired',
    );
  }
}

class _CountingRefreshAuthService extends AuthService {
  _CountingRefreshAuthService({required super.sessionStore})
    : super(useMockBackend: true);

  int refreshCalls = 0;

  @override
  Future<AuthSession> refresh({
    required String refreshToken,
    required String deviceId,
  }) async {
    refreshCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return super.refresh(refreshToken: refreshToken, deviceId: deviceId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  ProviderContainer createContainer({
    AuthService? authService,
    SessionStore? store,
  }) {
    final SessionStore sessionStore = store ?? SessionStore();
    return ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWith((Ref ref) => sessionStore),
        deviceIdentityServiceProvider.overrideWith(
          (Ref ref) => DeviceIdentityService(),
        ),
        authServiceProvider.overrideWith(
          (Ref ref) =>
              authService ??
              AuthService(sessionStore: sessionStore, useMockBackend: true),
        ),
      ],
    );
  }

  Future<void> enterPinAndSubmit(
    AuthController controller, {
    String pin = '123',
  }) async {
    for (final String digit in pin.split('')) {
      controller.appendDigit(digit);
    }
    await controller.submit();
  }

  test('reports an error when PIN is incomplete', () async {
    final ProviderContainer container = createContainer();
    addTearDown(container.dispose);
    final AuthController controller = container.read(
      authControllerProvider.notifier,
    );

    controller.appendDigit('1');
    await controller.submit();

    final AuthState state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.error);
    expect(state.errorMessage, contains('PIN'));
  });

  test('enters loading then authenticates for a valid mock login', () async {
    final ProviderContainer container = createContainer();
    addTearDown(container.dispose);
    final AuthController controller = container.read(
      authControllerProvider.notifier,
    );

    controller.appendDigit('1');
    controller.appendDigit('2');
    controller.appendDigit('3');

    final Future<void> submission = controller.submit();
    expect(container.read(authControllerProvider).status, AuthStatus.loading);

    await submission;
    final AuthState state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.authenticated);
    expect(state.session?.staff.id, 'staff_1');
    expect(state.session?.restaurant.id, '123');
    expect(state.session?.outlet.id, '1');
    expect(state.deviceId, isNotNull);
    expect(state.session?.accessToken, isNotEmpty);
  });

  test('maps INVALID_PIN without lockout UI', () async {
    final ProviderContainer container = createContainer();
    addTearDown(container.dispose);
    final AuthController controller = container.read(
      authControllerProvider.notifier,
    );

    await enterPinAndSubmit(controller, pin: '000');
    final AuthState state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.error);
    expect(state.errorMessage, 'Incorrect PIN. Please try again.');
  });

  test('refreshSession updates access token on success', () async {
    final ProviderContainer container = createContainer();
    addTearDown(container.dispose);
    final AuthController controller = container.read(
      authControllerProvider.notifier,
    );
    await enterPinAndSubmit(controller);

    final String? before =
        container.read(authControllerProvider).session?.accessToken;
    final String? token = await controller.refreshSession();

    expect(token, isNotNull);
    expect(token, isNot(before));
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.authenticated,
    );
    expect(container.read(authControllerProvider).session?.accessToken, token);
  });

  test('refreshSession failure surfaces session-expired state', () async {
    final SessionStore store = SessionStore();
    final _FailingRefreshAuthService failing = _FailingRefreshAuthService(
      sessionStore: store,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWith((Ref ref) => store),
        deviceIdentityServiceProvider.overrideWith(
          (Ref ref) => DeviceIdentityService(),
        ),
        authServiceProvider.overrideWith((Ref ref) => failing),
      ],
    );
    addTearDown(container.dispose);

    final AuthController controller = container.read(
      authControllerProvider.notifier,
    );
    await enterPinAndSubmit(controller);
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.authenticated,
    );

    final String? token = await controller.refreshSession();
    expect(token, isNull);
    expect(failing.refreshCalls, 1);

    final AuthState state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.error);
    expect(state.session, isNull);
    expect(state.errorMessage, AuthController.sessionExpiredMessage);
  });

  test('concurrent refreshSession calls share one in-flight refresh', () async {
    final SessionStore store = SessionStore();
    final _CountingRefreshAuthService counting = _CountingRefreshAuthService(
      sessionStore: store,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWith((Ref ref) => store),
        deviceIdentityServiceProvider.overrideWith(
          (Ref ref) => DeviceIdentityService(),
        ),
        authServiceProvider.overrideWith((Ref ref) => counting),
      ],
    );
    addTearDown(container.dispose);

    final AuthController controller = container.read(
      authControllerProvider.notifier,
    );
    await enterPinAndSubmit(controller);

    final List<String?> tokens = await Future.wait(<Future<String?>>[
      controller.refreshSession(),
      controller.refreshSession(),
      controller.refreshSession(),
    ]);

    expect(counting.refreshCalls, 1);
    expect(tokens[0], isNotNull);
    expect(tokens[1], tokens[0]);
    expect(tokens[2], tokens[0]);
  });

  AuthSession persistedSession({required DateTime expiresAt}) {
    return AuthSession(
      accessToken: 'persisted-access',
      refreshToken: 'persisted-refresh',
      expiresAt: expiresAt,
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

  test('restoreSession authenticates when access token is still valid', () async {
    final SessionStore store = SessionStore();
    await store.save(
      persistedSession(
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
    );
    final ProviderContainer container = createContainer(store: store);
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).restoreSession();

    final AuthState state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.authenticated);
    expect(state.session?.accessToken, 'persisted-access');
    expect(state.deviceId, isNotNull);
  });

  test('restoreSession refreshes when access token is expired', () async {
    final SessionStore store = SessionStore();
    await store.save(
      persistedSession(
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      ),
    );
    final ProviderContainer container = createContainer(store: store);
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).restoreSession();

    final AuthState state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.authenticated);
    expect(state.session?.accessToken, isNot('persisted-access'));
    expect(state.session?.accessToken, isNotEmpty);
  });

  test('restoreSession logs out when refresh fails', () async {
    final SessionStore store = SessionStore();
    await store.save(
      persistedSession(
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      ),
    );
    final _FailingRefreshAuthService failing = _FailingRefreshAuthService(
      sessionStore: store,
    );
    final ProviderContainer container = createContainer(
      store: store,
      authService: failing,
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).restoreSession();

    final AuthState state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.error);
    expect(state.session, isNull);
    expect(state.errorMessage, AuthController.sessionExpiredMessage);
    expect(failing.refreshCalls, 1);
    expect(await store.load(), isNull);
  });

  test('logout clears the persisted session', () async {
    final SessionStore store = SessionStore();
    final ProviderContainer container = createContainer(store: store);
    addTearDown(container.dispose);
    final AuthController controller = container.read(
      authControllerProvider.notifier,
    );

    await enterPinAndSubmit(controller);
    expect(await store.load(), isNotNull);

    await controller.logout();

    expect(await store.load(), isNull);
    expect(container.read(authControllerProvider).status, AuthStatus.idle);
    expect(container.read(authControllerProvider).session, isNull);
  });

  test('restoreSession stays idle when nothing is persisted', () async {
    final ProviderContainer container = createContainer();
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).restoreSession();

    final AuthState state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.idle);
    expect(state.session, isNull);
  });

  test('logout does not clear saved server config', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SessionStore store = SessionStore();
    final ServerConfigService servers = ServerConfigService();
    await servers.save(
      const ServerConfig(ipAddress: '192.168.1.100', port: '8000'),
    );
    final ProviderContainer container = createContainer(store: store);
    addTearDown(container.dispose);
    final AuthController controller = container.read(
      authControllerProvider.notifier,
    );

    await enterPinAndSubmit(controller);
    await controller.logout();

    expect(await store.load(), isNull);
    final ServerConfig? saved = await servers.load();
    expect(saved?.hostPort, '192.168.1.100:8000');
  });

  test('logout allows restoreSession to run again for a later session', () async {
    final SessionStore store = SessionStore();
    await store.save(
      persistedSession(
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
    );
    final ProviderContainer container = createContainer(store: store);
    addTearDown(container.dispose);
    final AuthController controller = container.read(
      authControllerProvider.notifier,
    );

    await controller.restoreSession();
    expect(container.read(authControllerProvider).status, AuthStatus.authenticated);

    await controller.logout();
    await store.save(
      persistedSession(
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
    );
    await controller.restoreSession();

    expect(
      container.read(authControllerProvider).status,
      AuthStatus.authenticated,
    );
  });
}
