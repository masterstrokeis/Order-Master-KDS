import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/core/utils/order_title_number.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/order_title_number_preference_service.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Order title number defaults to display and persists KOT', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pumpAppearance(tester);

    final Finder displayChip = find.byKey(
      const Key('order-title-number-displayNumber'),
    );
    final Finder priorityChip = find.byKey(
      const Key('order-title-number-kotNumber'),
    );
    expect(displayChip, findsOneWidget);
    expect(priorityChip, findsOneWidget);
    expect(
      container.read(orderTitleNumberSourceProvider),
      OrderTitleNumberSource.displayNumber,
    );

    await tester.ensureVisible(priorityChip);
    await tester.pumpAndSettle();
    await tester.tap(priorityChip);
    await tester.pumpAndSettle();

    expect(
      container.read(orderTitleNumberSourceProvider),
      OrderTitleNumberSource.kotNumber,
    );
    final OrderTitleNumberPreferenceService prefs =
        OrderTitleNumberPreferenceService();
    expect(await prefs.load(), OrderTitleNumberSource.kotNumber);
  });
}

Future<ProviderContainer> _pumpAppearance(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  final UrgencySettingsService urgencyService = UrgencySettingsService();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      urgencySettingsServiceProvider.overrideWith((Ref ref) => urgencyService),
      urgencySettingsProvider.overrideWith(
        () => UrgencySettingsController(UrgencySettings.defaults),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: appLightTheme,
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
