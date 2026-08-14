import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  ProviderContainer createContainer({UrgencySettings? seed}) {
    final UrgencySettingsService service = UrgencySettingsService();
    return ProviderContainer(
      overrides: [
        urgencySettingsServiceProvider.overrideWith((Ref ref) => service),
        urgencySettingsProvider.overrideWith(
          () => UrgencySettingsController(seed ?? UrgencySettings.defaults),
        ),
      ],
    );
  }

  test('incrementing warning bumps critical when needed', () async {
    final ProviderContainer container = createContainer(
      seed: UrgencySettings.normalized(
        warningMinutes: 5,
        criticalMinutes: 6,
        warningColorValue: 1,
        criticalColorValue: 2,
      ),
    );
    addTearDown(container.dispose);
    final UrgencySettingsController controller = container.read(
      urgencySettingsProvider.notifier,
    );

    await controller.setWarningMinutes(6);

    final UrgencySettings state = container.read(urgencySettingsProvider);
    expect(state.warningMinutes, 6);
    expect(state.criticalMinutes, 7);
  });

  test('decrementing critical below warning+1 is a no-op', () async {
    final UrgencySettings seed = UrgencySettings.normalized(
      warningMinutes: 5,
      criticalMinutes: 6,
      warningColorValue: 1,
      criticalColorValue: 2,
    );
    final ProviderContainer container = createContainer(seed: seed);
    addTearDown(container.dispose);
    final UrgencySettingsController controller = container.read(
      urgencySettingsProvider.notifier,
    );

    await controller.setCriticalMinutes(4);

    expect(container.read(urgencySettingsProvider), seed);
  });

  test('resetToDefaults restores UrgencySettings.defaults', () async {
    final ProviderContainer container = createContainer(
      seed: UrgencySettings.normalized(
        warningMinutes: 20,
        criticalMinutes: 40,
        warningColorValue: 11,
        criticalColorValue: 22,
      ),
    );
    addTearDown(container.dispose);
    final UrgencySettingsController controller = container.read(
      urgencySettingsProvider.notifier,
    );

    await controller.resetToDefaults();

    expect(
      container.read(urgencySettingsProvider),
      UrgencySettings.defaults,
    );
  });

  test('setWarningMinutes persists through the service', () async {
    final ProviderContainer container = createContainer();
    addTearDown(container.dispose);
    final UrgencySettingsController controller = container.read(
      urgencySettingsProvider.notifier,
    );
    final UrgencySettingsService service = container.read(
      urgencySettingsServiceProvider,
    );

    await controller.setWarningMinutes(8);

    final UrgencySettings loaded = await service.load();
    expect(loaded.warningMinutes, 8);
    expect(loaded.criticalMinutes, greaterThan(8));
  });
}
