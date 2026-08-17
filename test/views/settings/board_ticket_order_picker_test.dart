import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/core/utils/board_ticket_order.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/board_ticket_order_preference_service.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Ticket order defaults to oldest first and persists newest', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pumpAppearance(tester);

    final Finder oldestChip = find.byKey(
      const Key('board-ticket-order-oldestFirst'),
    );
    final Finder newestChip = find.byKey(
      const Key('board-ticket-order-newestFirst'),
    );
    expect(oldestChip, findsOneWidget);
    expect(newestChip, findsOneWidget);
    expect(
      container.read(boardTicketOrderProvider),
      BoardTicketOrder.oldestFirst,
    );

    await tester.ensureVisible(newestChip);
    await tester.pumpAndSettle();
    await tester.tap(newestChip);
    await tester.pumpAndSettle();

    expect(
      container.read(boardTicketOrderProvider),
      BoardTicketOrder.newestFirst,
    );
    final BoardTicketOrderPreferenceService prefs =
        BoardTicketOrderPreferenceService();
    expect(await prefs.load(), BoardTicketOrder.newestFirst);
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
