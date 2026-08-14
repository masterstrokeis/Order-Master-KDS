import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/urgency_settings.dart';
import '../services/urgency_settings_service.dart';

final Provider<UrgencySettingsService> urgencySettingsServiceProvider =
    Provider<UrgencySettingsService>((Ref ref) => UrgencySettingsService());

/// Owns device-local urgency thresholds/colors and persists each change.
///
/// Providers live here (same as AuthController) so the Notifier can read the
/// service without a circular import through providers.dart. providers.dart
/// re-exports them for app-wide discovery.
class UrgencySettingsController extends Notifier<UrgencySettings> {
  UrgencySettingsController([this._seed]);

  final UrgencySettings? _seed;

  UrgencySettingsService get _service =>
      ref.read(urgencySettingsServiceProvider);

  @override
  UrgencySettings build() => _seed ?? UrgencySettings.defaults;

  Future<void> setWarningMinutes(int minutes) async {
    final UrgencySettings next = state.copyWith(warningMinutes: minutes);
    if (next == state) {
      return;
    }
    state = next;
    await _service.save(state);
  }

  Future<void> setCriticalMinutes(int minutes) async {
    final UrgencySettings next = state.copyWith(criticalMinutes: minutes);
    if (next == state) {
      return;
    }
    state = next;
    await _service.save(state);
  }

  Future<void> setWarningColor(Color color) async {
    final UrgencySettings next = state.copyWith(
      warningColorValue: color.toARGB32(),
    );
    if (next == state) {
      return;
    }
    state = next;
    await _service.save(state);
  }

  Future<void> setCriticalColor(Color color) async {
    final UrgencySettings next = state.copyWith(
      criticalColorValue: color.toARGB32(),
    );
    if (next == state) {
      return;
    }
    state = next;
    await _service.save(state);
  }

  Future<void> resetToDefaults() async {
    final UrgencySettings next = UrgencySettings.defaults;
    if (next == state) {
      return;
    }
    state = next;
    await _service.save(state);
  }
}

final NotifierProvider<UrgencySettingsController, UrgencySettings>
urgencySettingsProvider =
    NotifierProvider<UrgencySettingsController, UrgencySettings>(
      UrgencySettingsController.new,
    );
