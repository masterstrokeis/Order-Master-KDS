import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/core/theme/urgency_color_presets.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/cancelled_display_preference_service.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  UrgencySettings nonDefaultSeed() {
    return UrgencySettings.normalized(
      warningMinutes: 5,
      criticalMinutes: 10,
      warningColorValue: UrgencyColorPresets.warningColorPresets.first.toARGB32(),
      criticalColorValue:
          UrgencyColorPresets.criticalColorPresets[1].toARGB32(),
    );
  }

  Future<ProviderContainer> pumpSettings(
    WidgetTester tester, {
    required UrgencySettings seed,
    ThemeData? theme,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final UrgencySettingsService service = UrgencySettingsService();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        urgencySettingsServiceProvider.overrideWith((Ref ref) => service),
        urgencySettingsProvider.overrideWith(
          () => UrgencySettingsController(seed),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? appLightTheme,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> expandOrderTiming(WidgetTester tester) async {
    await tapVisible(tester, find.byKey(const Key('order-timing-header')));
  }

  testWidgets('Order Timing starts collapsed and expands on tap', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester, seed: nonDefaultSeed());

    expect(
      find.byKey(const Key('warning-stepper-value')),
      findsNothing,
      reason: 'Stepper should be hidden while collapsed',
    );

    await expandOrderTiming(tester);

    expect(
      find.byKey(const Key('warning-stepper-value')),
      findsOneWidget,
      reason: 'Stepper should be visible after expanding',
    );
  });

  testWidgets('warning + increases displayed minutes', (WidgetTester tester) async {
    await pumpSettings(tester, seed: nonDefaultSeed());
    await expandOrderTiming(tester);

    expect(find.byKey(const Key('warning-stepper-value')), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('warning-stepper-inc')));

    expect(find.text('6 min'), findsOneWidget);
  });

  testWidgets('critical color swatch updates selection', (WidgetTester tester) async {
    final ProviderContainer container = await pumpSettings(
      tester,
      seed: nonDefaultSeed(),
    );
    await expandOrderTiming(tester);

    final Color target = UrgencyColorPresets.criticalColorPresets[2];
    await tapVisible(tester, find.byKey(const Key('critical-swatch-2')));

    expect(
      container.read(urgencySettingsProvider).criticalColorValue,
      target.toARGB32(),
    );
  });

  testWidgets('reset to defaults restores defaults after confirm', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpSettings(
      tester,
      seed: nonDefaultSeed(),
    );
    await expandOrderTiming(tester);

    expect(find.text('5 min'), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('order-timing-reset')));
    await tapVisible(
      tester,
      find.byKey(const Key('order-timing-reset-confirm')),
    );

    expect(container.read(urgencySettingsProvider), UrgencySettings.defaults);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('warning-stepper-value')))
          .data,
      '${UrgencySettings.defaults.warningMinutes} min',
    );
  });

  testWidgets('Order Timing section renders correctly in light theme', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final UrgencySettingsService service = UrgencySettingsService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          urgencySettingsServiceProvider.overrideWith((Ref ref) => service),
          urgencySettingsProvider.overrideWith(
            () => UrgencySettingsController(UrgencySettings.defaults),
          ),
        ],
        child: MaterialApp(
          theme: appLightTheme,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order Timing'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('order-timing-header')));

    expect(find.byKey(const Key('warning-stepper-value')), findsOneWidget);
    expect(find.byKey(const Key('critical-stepper-value')), findsOneWidget);
    expect(find.byKey(const Key('order-timing-reset')), findsOneWidget);
  });

  testWidgets('Order Timing section renders correctly in dark theme', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final UrgencySettingsService service = UrgencySettingsService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          urgencySettingsServiceProvider.overrideWith((Ref ref) => service),
          urgencySettingsProvider.overrideWith(
            () => UrgencySettingsController(UrgencySettings.defaults),
          ),
        ],
        child: MaterialApp(
          theme: appDarkTheme,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order Timing'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('order-timing-header')));

    expect(find.byKey(const Key('warning-stepper-value')), findsOneWidget);
    expect(find.byKey(const Key('critical-stepper-value')), findsOneWidget);
    expect(find.byKey(const Key('order-timing-reset')), findsOneWidget);
  });

  testWidgets('cancelled display chips default to 30 sec and persist 1 min', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpSettings(
      tester,
      seed: UrgencySettings.defaults,
    );
    await expandOrderTiming(tester);

    expect(find.byKey(const Key('cancelled-display-30')), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('cancelled-display-60')));

    expect(container.read(cancelledDisplaySecondsProvider), 60);
    expect(await CancelledDisplayPreferenceService().load(), 60);

    await tapVisible(tester, find.byKey(const Key('cancelled-display-15')));
    expect(container.read(cancelledDisplaySecondsProvider), 15);

    await tapVisible(tester, find.byKey(const Key('cancelled-display-120')));
    expect(container.read(cancelledDisplaySecondsProvider), 120);
  });
}
