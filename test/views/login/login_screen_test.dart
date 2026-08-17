import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/auth_controller.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/models/auth_session.dart';
import 'package:order_master_kds/models/kds_connection_failure.dart';
import 'package:order_master_kds/models/server_config.dart';
import 'package:order_master_kds/providers/server_config_providers.dart';
import 'package:order_master_kds/services/auth_service.dart';
import 'package:order_master_kds/services/device_identity_service.dart';
import 'package:order_master_kds/services/session_store.dart';
import 'package:order_master_kds/views/login/login_screen.dart';
import 'package:order_master_kds/views/login/widgets/login_connectivity_dialog.dart';
import 'package:order_master_kds/views/server_setup/server_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ConnectivityFailingAuthService extends AuthService {
  _ConnectivityFailingAuthService({required super.sessionStore})
    : super(useMockBackend: true);

  @override
  Future<AuthSession> login({
    required String pin,
    required String deviceId,
  }) async {
    throw const KdsConnectionFailure();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<ProviderContainer> pumpLogin(
    WidgetTester tester, {
    AuthService? authService,
    ServerConfig? serverConfig,
  }) async {
    final SessionStore store = SessionStore();
    final ProviderContainer container = ProviderContainer(
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
    addTearDown(container.dispose);
    if (serverConfig != null) {
      container.read(serverConfigProvider.notifier).state = serverConfig;
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: appLightTheme,
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final String digit in pin.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
  }

  testWidgets('connectivity failure shows dialog with Change server navigation',
      (WidgetTester tester) async {
    final SessionStore store = SessionStore();
    await pumpLogin(
      tester,
      authService: _ConnectivityFailingAuthService(sessionStore: store),
      serverConfig: const ServerConfig(ipAddress: '192.168.1.50', port: '8000'),
    );

    await enterPin(tester, '123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginConnectivityDialog), findsOneWidget);
    expect(find.text('Server unreachable'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login-connectivity-change-server')));
    await tester.pumpAndSettle();

    expect(find.byType(ServerSetupScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('server-ip-field'))).controller
          ?.text,
      '192.168.1.50',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('server-port-field')))
          .controller
          ?.text,
      '8000',
    );
  });

  testWidgets('wrong PIN does not show connectivity dialog', (
    WidgetTester tester,
  ) async {
    await pumpLogin(
      tester,
      serverConfig: const ServerConfig(ipAddress: '192.168.1.50', port: '8000'),
    );

    await enterPin(tester, '000');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginConnectivityDialog), findsNothing);
    expect(find.text('Incorrect PIN. Please try again.'), findsOneWidget);
  });

  testWidgets('server setup icon opens ServerSetup pre-filled at any time', (
    WidgetTester tester,
  ) async {
    await pumpLogin(
      tester,
      serverConfig: const ServerConfig(ipAddress: '10.0.0.5', port: '5012'),
    );

    expect(find.byType(LoginConnectivityDialog), findsNothing);

    await tester.tap(find.byKey(const Key('login-server-setup')));
    await tester.pumpAndSettle();

    expect(find.byType(ServerSetupScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('server-ip-field'))).controller
          ?.text,
      '10.0.0.5',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('server-port-field')))
          .controller
          ?.text,
      '5012',
    );
  });
}
