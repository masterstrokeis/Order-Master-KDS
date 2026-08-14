import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/controllers/voice_announcement_controller.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/core/utils/order_announcement.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/services/announcement_preference_service.dart';
import 'package:order_master_kds/services/kds_tts_service.dart';
import 'package:order_master_kds/services/order_update_pulse_preference_service.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Announcements switch defaults on and persists off', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpNotifications(tester);

    final Finder switchFinder = find.byKey(
      const Key('announcements-enabled-switch'),
    );
    expect(switchFinder, findsOneWidget);
    expect(_switchValue(tester, switchFinder), isTrue);

    await tester.ensureVisible(switchFinder);
    await tester.pumpAndSettle();
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(harness.container.read(announcementsEnabledProvider), isFalse);
    expect(_switchValue(tester, switchFinder), isFalse);

    final AnnouncementPreferenceService prefs = AnnouncementPreferenceService();
    expect(await prefs.load(), isFalse);
  });

  testWidgets('Test announcement speaks even when muted', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpNotifications(
      tester,
      announcementsEnabled: false,
    );

    final Finder button = find.byKey(const Key('test-announcement-button'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(harness.tts.spoken, <String>[testAnnouncementLine]);
  });

  testWidgets('pulse stepper defaults to 30 sec and persists increment', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpNotifications(tester);

    expect(find.byKey(const Key('pulse-stepper-value')), findsOneWidget);
    expect(find.text('30 sec'), findsOneWidget);

    final Finder increment = find.byKey(const Key('pulse-stepper-inc'));
    await tester.ensureVisible(increment);
    await tester.pumpAndSettle();
    await tester.tap(increment);
    await tester.pumpAndSettle();

    expect(harness.container.read(orderUpdatePulseSecondsProvider), 31);
    expect(find.text('31 sec'), findsOneWidget);

    final OrderUpdatePulsePreferenceService prefs =
        OrderUpdatePulsePreferenceService();
    expect(await prefs.load(), 31);
  });
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

class _Harness {
  const _Harness({required this.container, required this.tts});

  final ProviderContainer container;
  final _RecordingKdsTts tts;
}

Future<_Harness> _pumpNotifications(
  WidgetTester tester, {
  bool announcementsEnabled = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  final _RecordingKdsTts tts = _RecordingKdsTts();
  final UrgencySettingsService urgencyService = UrgencySettingsService();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      urgencySettingsServiceProvider.overrideWith((Ref ref) => urgencyService),
      urgencySettingsProvider.overrideWith(
        () => UrgencySettingsController(UrgencySettings.defaults),
      ),
      announcementsEnabledProvider.overrideWith(
        (Ref ref) => announcementsEnabled,
      ),
      kdsTtsServiceProvider.overrideWith((Ref ref) => tts),
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
  return _Harness(container: container, tts: tts);
}

class _RecordingKdsTts extends KdsTtsService {
  _RecordingKdsTts() : super(tts: _UnusedFlutterTts(), isIos: false);

  final List<String> spoken = <String>[];

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }
}

class _UnusedFlutterTts extends FlutterTts {}
