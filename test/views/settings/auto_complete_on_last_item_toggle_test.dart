import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/auto_complete_on_last_item_preference_service.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'Complete ticket when last item is struck switch defaults on and persists off',
    (WidgetTester tester) async {
      final ProviderContainer container = await _pumpAppearance(tester);

      final Finder switchFinder = find.byKey(
        const Key('auto-complete-on-last-item-switch'),
      );
      expect(switchFinder, findsOneWidget);
      expect(_switchValue(tester, switchFinder), isTrue);

      await tester.ensureVisible(switchFinder);
      await tester.pumpAndSettle();
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(container.read(autoCompleteOnLastItemProvider), isFalse);
      expect(_switchValue(tester, switchFinder), isFalse);

      final AutoCompleteOnLastItemPreferenceService prefs =
          AutoCompleteOnLastItemPreferenceService();
      expect(await prefs.load(), isFalse);
    },
  );
}

bool _switchValue(WidgetTester tester, Finder finder) {
  final Widget widget = tester.widget(finder);
  if (widget is Switch) {
    return widget.value;
  }
  if (widget is CupertinoSwitch) {
    return widget.value;
  }
  fail('Expected Switch or CupertinoSwitch, got ${widget.runtimeType}');
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
