import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/constants/kds_timing.dart';
import 'package:order_master_kds/core/theme/app_colors.dart';
import 'package:order_master_kds/models/urgency_settings.dart';

void main() {
  group('UrgencySettings.defaults', () {
    test('matches KdsTiming and AppColors urgency tokens', () {
      final UrgencySettings settings = UrgencySettings.defaults;

      expect(
        settings.warningMinutes,
        KdsTiming.warningThreshold.inMinutes,
      );
      expect(
        settings.criticalMinutes,
        KdsTiming.criticalThreshold.inMinutes,
      );
      expect(settings.warningColorValue, AppColors.urgencyWarning.toARGB32());
      expect(
        settings.criticalColorValue,
        AppColors.urgencyCritical.toARGB32(),
      );
      expect(settings.criticalMinutes, greaterThan(settings.warningMinutes));
    });
  });

  group('UrgencySettings.normalized', () {
    test('clamps minutes to 1..120 and keeps critical above warning', () {
      final UrgencySettings low = UrgencySettings.normalized(
        warningMinutes: 0,
        criticalMinutes: 0,
        warningColorValue: 1,
        criticalColorValue: 2,
      );
      expect(low.warningMinutes, UrgencySettings.minMinutes);
      expect(low.criticalMinutes, UrgencySettings.minMinutes + 1);

      final UrgencySettings high = UrgencySettings.normalized(
        warningMinutes: 200,
        criticalMinutes: 200,
        warningColorValue: 1,
        criticalColorValue: 2,
      );
      expect(high.warningMinutes, UrgencySettings.maxMinutes - 1);
      expect(high.criticalMinutes, UrgencySettings.maxMinutes);
    });

    test('copyWith re-normalizes critical when warning rises past it', () {
      final UrgencySettings updated = UrgencySettings.defaults.copyWith(
        warningMinutes: 10,
        criticalMinutes: 5,
      );

      expect(updated.warningMinutes, 10);
      expect(updated.criticalMinutes, 11);
    });
  });

  group('UrgencySettings JSON', () {
    test('round-trips through toJson / fromJson', () {
      final UrgencySettings original = UrgencySettings.normalized(
        warningMinutes: 5,
        criticalMinutes: 12,
        warningColorValue: AppColors.urgencyWarning.toARGB32(),
        criticalColorValue: AppColors.urgencyCritical.toARGB32(),
      );

      final UrgencySettings restored = UrgencySettings.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(restored, original);
    });

    test('fromJson accepts numeric doubles from JSON', () {
      final UrgencySettings settings = UrgencySettings.fromJson(
        <String, dynamic>{
          UrgencySettings.jsonWarningMinutes: 3.0,
          UrgencySettings.jsonCriticalMinutes: 8.0,
          UrgencySettings.jsonWarningColorValue: 10.0,
          UrgencySettings.jsonCriticalColorValue: 20.0,
        },
      );

      expect(settings.warningMinutes, 3);
      expect(settings.criticalMinutes, 8);
      expect(settings.warningColorValue, 10);
      expect(settings.criticalColorValue, 20);
    });
  });
}
