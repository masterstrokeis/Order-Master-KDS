import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/theme/app_colors.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UrgencySettingsService', () {
    test('load returns defaults when prefs are empty', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final UrgencySettingsService service = UrgencySettingsService();

      expect(await service.load(), UrgencySettings.defaults);
    });

    test('save then load round-trips settings', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final UrgencySettingsService service = UrgencySettingsService();
      final UrgencySettings saved = UrgencySettings.normalized(
        warningMinutes: 4,
        criticalMinutes: 9,
        warningColorValue: AppColors.urgencyWarning.toARGB32(),
        criticalColorValue: AppColors.urgencyCritical.toARGB32(),
      );

      await service.save(saved);

      expect(await service.load(), saved);
    });

    test('load returns defaults for corrupt JSON', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        UrgencySettingsService.prefsKey: '{not-json',
      });
      final UrgencySettingsService service = UrgencySettingsService();

      expect(await service.load(), UrgencySettings.defaults);
    });

    test('load returns defaults for non-object JSON', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        UrgencySettingsService.prefsKey: jsonEncode(<int>[1, 2, 3]),
      });
      final UrgencySettingsService service = UrgencySettingsService();

      expect(await service.load(), UrgencySettings.defaults);
    });

    test('load returns defaults when required fields are missing', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        UrgencySettingsService.prefsKey: jsonEncode(<String, dynamic>{
          'warningMinutes': 5,
        }),
      });
      final UrgencySettingsService service = UrgencySettingsService();

      expect(await service.load(), UrgencySettings.defaults);
    });

    test('load normalizes out-of-range minutes from stored JSON', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        UrgencySettingsService.prefsKey: jsonEncode(<String, dynamic>{
          UrgencySettings.jsonWarningMinutes: 0,
          UrgencySettings.jsonCriticalMinutes: 0,
          UrgencySettings.jsonWarningColorValue: 11,
          UrgencySettings.jsonCriticalColorValue: 22,
        }),
      });
      final UrgencySettingsService service = UrgencySettingsService();
      final UrgencySettings loaded = await service.load();

      expect(loaded.warningMinutes, UrgencySettings.minMinutes);
      expect(loaded.criticalMinutes, UrgencySettings.minMinutes + 1);
      expect(loaded.warningColorValue, 11);
      expect(loaded.criticalColorValue, 22);
    });
  });
}
