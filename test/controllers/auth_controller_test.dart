import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/auth_controller.dart';
import 'package:order_master_kds/models/auth_session.dart';
import 'package:order_master_kds/models/kds_api_error.dart';
import 'package:order_master_kds/services/auth_service.dart';
import 'package:order_master_kds/services/device_identity_service.dart';
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

  ProviderContainer createContainer({AuthService? authService}) {
    final SessionStore store = SessionStore();
    return ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWith((Ref ref) => store),
        deviceIdentityServiceProvider.overrideWith(
          (Ref ref) => DeviceIdentityService(),
        ),
        authServiceProvider.overrideWith(
          (Ref ref) =>
              authService ??
              AuthService(sessionStore: store, useMockBackend: true),
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
}
