import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/kitchen_display/kitchen_display_screen.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/station_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<(PhysicalKeyboardKey, LogicalKeyboardKey, LogicalKeyboardKey)>
_numpadKeys = <(PhysicalKeyboardKey, LogicalKeyboardKey, LogicalKeyboardKey)>[
  (
    PhysicalKeyboardKey.numpad0,
    LogicalKeyboardKey.numpad0,
    LogicalKeyboardKey.insert,
  ),
  (
    PhysicalKeyboardKey.numpad1,
    LogicalKeyboardKey.numpad1,
    LogicalKeyboardKey.end,
  ),
  (
    PhysicalKeyboardKey.numpad2,
    LogicalKeyboardKey.numpad2,
    LogicalKeyboardKey.arrowDown,
  ),
  (
    PhysicalKeyboardKey.numpad3,
    LogicalKeyboardKey.numpad3,
    LogicalKeyboardKey.pageDown,
  ),
  (
    PhysicalKeyboardKey.numpad4,
    LogicalKeyboardKey.numpad4,
    LogicalKeyboardKey.arrowLeft,
  ),
  (
    PhysicalKeyboardKey.numpad5,
    LogicalKeyboardKey.numpad5,
    LogicalKeyboardKey.clear,
  ),
  (
    PhysicalKeyboardKey.numpad6,
    LogicalKeyboardKey.numpad6,
    LogicalKeyboardKey.arrowRight,
  ),
  (
    PhysicalKeyboardKey.numpad7,
    LogicalKeyboardKey.numpad7,
    LogicalKeyboardKey.home,
  ),
  (
    PhysicalKeyboardKey.numpad8,
    LogicalKeyboardKey.numpad8,
    LogicalKeyboardKey.arrowUp,
  ),
  (
    PhysicalKeyboardKey.numpad9,
    LogicalKeyboardKey.numpad9,
    LogicalKeyboardKey.pageUp,
  ),
  (
    PhysicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.enter,
  ),
  (
    PhysicalKeyboardKey.numpadAdd,
    LogicalKeyboardKey.numpadAdd,
    LogicalKeyboardKey.numpadAdd,
  ),
  (
    PhysicalKeyboardKey.numpadSubtract,
    LogicalKeyboardKey.numpadSubtract,
    LogicalKeyboardKey.numpadSubtract,
  ),
  (
    PhysicalKeyboardKey.numpadMultiply,
    LogicalKeyboardKey.numpadMultiply,
    LogicalKeyboardKey.numpadMultiply,
  ),
  (
    PhysicalKeyboardKey.numpadDecimal,
    LogicalKeyboardKey.numpadDecimal,
    LogicalKeyboardKey.delete,
  ),
  (
    PhysicalKeyboardKey.numpadDivide,
    LogicalKeyboardKey.numpadDivide,
    LogicalKeyboardKey.numpadDivide,
  ),
  (
    PhysicalKeyboardKey.numLock,
    LogicalKeyboardKey.numLock,
    LogicalKeyboardKey.numLock,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'clicking the station dropdown then sending numpad keys does not change station',
    (WidgetTester tester) async {
      final ProviderContainer container = await _pumpKitchenDisplay(tester);
      final String? before = container.read(selectedStationProvider);

      await tester.tap(find.byType(StationSelector));
      await tester.pumpAndSettle();

      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator),
      );
      if (navigator.canPop()) {
        navigator.pop();
        await tester.pumpAndSettle();
      }

      for (final (
            PhysicalKeyboardKey physical,
            LogicalKeyboardKey numLockOn,
            LogicalKeyboardKey numLockOff,
          )
          in _numpadKeys) {
        await _dispatchDown(tester, logical: numLockOn, physical: physical);
        await _dispatchUp(tester, logical: numLockOn, physical: physical);
        await _dispatchDown(tester, logical: numLockOff, physical: physical);
        await _dispatchUp(tester, logical: numLockOff, physical: physical);
      }
      await tester.pump();

      expect(find.text('Cooking Station - 2'), findsNothing);
      expect(container.read(selectedStationProvider), before);
    },
  );
}

Future<void> _dispatchDown(
  WidgetTester tester, {
  required LogicalKeyboardKey logical,
  required PhysicalKeyboardKey physical,
}) async {
  _dispatchDirect(
    tester,
    KeyDownEvent(
      physicalKey: physical,
      logicalKey: logical,
      timeStamp: Duration.zero,
    ),
  );
}

Future<void> _dispatchUp(
  WidgetTester tester, {
  required LogicalKeyboardKey logical,
  required PhysicalKeyboardKey physical,
}) async {
  _dispatchDirect(
    tester,
    KeyUpEvent(
      physicalKey: physical,
      logicalKey: logical,
      timeStamp: Duration.zero,
    ),
  );
}

void _dispatchDirect(WidgetTester tester, KeyEvent event) {
  final Focus focus = tester.widget<Focus>(
    find.byKey(const Key('kds-keyboard-scope')),
  );
  focus.onKeyEvent!(focus.focusNode!, event);
}

Future<ProviderContainer> _pumpKitchenDisplay(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  final ProviderContainer container = ProviderContainer(
    overrides: [
      urgencySettingsServiceProvider.overrideWith(
        (Ref ref) => UrgencySettingsService(),
      ),
      urgencySettingsProvider.overrideWith(
        () => UrgencySettingsController(UrgencySettings.defaults),
      ),
      kdsClockProvider.overrideWith(
        (Ref ref) => Stream<DateTime>.value(DateTime.utc(2026, 8, 18, 12)),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: appLightTheme,
        home: const KitchenDisplayScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
