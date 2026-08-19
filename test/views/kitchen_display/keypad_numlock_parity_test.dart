import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/keypad_controller.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/models/keypad_state.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/kitchen_display/kitchen_display_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The 16 mapped numpad keys plus NumLock (unmapped), each with NumLock-ON
/// and NumLock-OFF logical keys for the same physical key.
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
    'each numpad physical key yields the same KeypadState with NumLock on or off',
    (WidgetTester tester) async {
      expect(_numpadKeys, hasLength(17));

      for (final (
            PhysicalKeyboardKey physical,
            LogicalKeyboardKey numLockOn,
            LogicalKeyboardKey numLockOff,
          )
          in _numpadKeys) {
        final KeypadState onState = await _stateAfterKey(
          tester,
          logical: numLockOn,
          physical: physical,
        );
        final KeypadState offState = await _stateAfterKey(
          tester,
          logical: numLockOff,
          physical: physical,
        );
        expect(
          _withoutTimestamps(offState),
          _withoutTimestamps(onState),
          reason: '$physical NumLock-off vs NumLock-on',
        );
      }
    },
  );
}

KeypadState _withoutTimestamps(KeypadState state) {
  return state.copyWith(clearDigitsAt: true, clearFlashUntil: true);
}

Future<KeypadState> _stateAfterKey(
  WidgetTester tester, {
  required LogicalKeyboardKey logical,
  required PhysicalKeyboardKey physical,
}) async {
  final ProviderContainer container = await _pumpKitchenDisplay(tester);
  await _dispatchDown(tester, logical: logical, physical: physical);
  await tester.pump();
  await _dispatchUp(tester, logical: logical, physical: physical);
  return container.read(keypadProvider);
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
