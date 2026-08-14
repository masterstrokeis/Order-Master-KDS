import 'package:flutter/material.dart';

import '../core/constants/kds_timing.dart';
import '../core/theme/app_colors.dart';

/// Device-local kitchen policy for order urgency thresholds and header colors.
///
/// Minutes are always clamped to [[minMinutes], [maxMinutes]] with
/// [criticalMinutes] > [warningMinutes]. Colors are stored as ARGB ints.
class UrgencySettings {
  const UrgencySettings({
    required this.warningMinutes,
    required this.criticalMinutes,
    required this.warningColorValue,
    required this.criticalColorValue,
  });

  static const int minMinutes = 1;
  static const int maxMinutes = 120;

  static const String jsonWarningMinutes = 'warningMinutes';
  static const String jsonCriticalMinutes = 'criticalMinutes';
  static const String jsonWarningColorValue = 'warningColorValue';
  static const String jsonCriticalColorValue = 'criticalColorValue';

  /// Current hardcoded board defaults ([KdsTiming] + [AppColors] urgency tokens).
  static UrgencySettings get defaults {
    return UrgencySettings.normalized(
      warningMinutes: KdsTiming.warningThreshold.inMinutes,
      criticalMinutes: KdsTiming.criticalThreshold.inMinutes,
      warningColorValue: AppColors.urgencyWarning.toARGB32(),
      criticalColorValue: AppColors.urgencyCritical.toARGB32(),
    );
  }

  /// Clamps minutes to [[minMinutes], [maxMinutes]] and ensures
  /// `criticalMinutes > warningMinutes`.
  factory UrgencySettings.normalized({
    required int warningMinutes,
    required int criticalMinutes,
    required int warningColorValue,
    required int criticalColorValue,
  }) {
    int warning = warningMinutes.clamp(minMinutes, maxMinutes);
    int critical = criticalMinutes.clamp(minMinutes, maxMinutes);
    if (critical <= warning) {
      if (warning >= maxMinutes) {
        warning = maxMinutes - 1;
        critical = maxMinutes;
      } else {
        critical = warning + 1;
      }
    }
    return UrgencySettings(
      warningMinutes: warning,
      criticalMinutes: critical,
      warningColorValue: warningColorValue,
      criticalColorValue: criticalColorValue,
    );
  }

  factory UrgencySettings.fromJson(Map<String, dynamic> json) {
    return UrgencySettings.normalized(
      warningMinutes: _readInt(json[jsonWarningMinutes]),
      criticalMinutes: _readInt(json[jsonCriticalMinutes]),
      warningColorValue: _readInt(json[jsonWarningColorValue]),
      criticalColorValue: _readInt(json[jsonCriticalColorValue]),
    );
  }

  final int warningMinutes;
  final int criticalMinutes;
  final int warningColorValue;
  final int criticalColorValue;

  Duration get warningThreshold => Duration(minutes: warningMinutes);
  Duration get criticalThreshold => Duration(minutes: criticalMinutes);

  Color get warningColor => Color(warningColorValue);
  Color get criticalColor => Color(criticalColorValue);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      jsonWarningMinutes: warningMinutes,
      jsonCriticalMinutes: criticalMinutes,
      jsonWarningColorValue: warningColorValue,
      jsonCriticalColorValue: criticalColorValue,
    };
  }

  UrgencySettings copyWith({
    int? warningMinutes,
    int? criticalMinutes,
    int? warningColorValue,
    int? criticalColorValue,
  }) {
    return UrgencySettings.normalized(
      warningMinutes: warningMinutes ?? this.warningMinutes,
      criticalMinutes: criticalMinutes ?? this.criticalMinutes,
      warningColorValue: warningColorValue ?? this.warningColorValue,
      criticalColorValue: criticalColorValue ?? this.criticalColorValue,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is UrgencySettings &&
        other.warningMinutes == warningMinutes &&
        other.criticalMinutes == criticalMinutes &&
        other.warningColorValue == warningColorValue &&
        other.criticalColorValue == criticalColorValue;
  }

  @override
  int get hashCode {
    return Object.hash(
      warningMinutes,
      criticalMinutes,
      warningColorValue,
      criticalColorValue,
    );
  }

  static int _readInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    throw FormatException('Expected int, got $raw');
  }
}
