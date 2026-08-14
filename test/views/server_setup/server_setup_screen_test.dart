import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/auth_controller.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/models/auth_session.dart';
import 'package:order_master_kds/models/restaurant_model.dart';
import 'package:order_master_kds/models/staff_model.dart';
import 'package:order_master_kds/providers/server_config_providers.dart';
import 'package:order_master_kds/services/auth_service.dart';
import 'package:order_master_kds/services/connection_check.dart';
import 'package:order_master_kds/services/device_identity_service.dart';
import 'package:order_master_kds/services/session_store.dart';
import 'package:order_master_kds/views/server_setup/server_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Save with an invalid IP shows an error and does not continue', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: appLightTheme,
          home: const ServerSetupScreen(),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('server-ip-field')), '192.168.1');
    await tester.enterText(find.byKey(const Key('server-port-field')), '8000');
    await tester.tap(find.byKey(const Key('server-save-button')));
    await tester.pump();

    expect(find.text('Enter a valid IPv4 address.'), findsOneWidget);
  });

  testWidgets('successful save clears leftover session and does not authenticate',
      (WidgetTester tester) async {
    final SessionStore store = SessionStore();
    await store.save(
      AuthSession(
        accessToken: 'leftover-access',
        refreshToken: 'leftover-refresh',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        staff: const Staff(
          id: 'staff_1',
          name: 'John',
          initials: 'JO',
        ),
        restaurant: const Restaurant(id: '123', name: 'Order Master'),
        outlet: const Outlet(id: '1', name: 'Main Counter'),
      ),
    );

    final ProviderContainer container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWith((Ref ref) => store),
        deviceIdentityServiceProvider.overrideWith(
          (Ref ref) => DeviceIdentityService(),
        ),
        authServiceProvider.overrideWith(
          (Ref ref) => AuthService(sessionStore: store, useMockBackend: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: appLightTheme,
          home: ServerSetupScreen(
            checkConnection: (String baseUrl) async {
              expect(baseUrl, 'http://192.168.1.100:8000');
              return const ConnectionCheckResult(ok: true);
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('server-ip-field')),
      '192.168.1.100',
    );
    await tester.enterText(find.byKey(const Key('server-port-field')), '8000');
    await tester.tap(find.byKey(const Key('server-save-button')));
    await tester.pumpAndSettle();

    expect(await store.load(), isNull);
    expect(container.read(authControllerProvider).status, AuthStatus.idle);
    expect(container.read(authControllerProvider).session, isNull);
    expect(
      container.read(serverConfigProvider)?.hostPort,
      '192.168.1.100:8000',
    );
  });
}
