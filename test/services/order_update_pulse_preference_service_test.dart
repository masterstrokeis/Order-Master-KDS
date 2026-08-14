import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/constants/kds_timing.dart';
import 'package:order_master_kds/services/order_update_pulse_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load returns 30 when prefs are empty', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final OrderUpdatePulsePreferenceService service =
        OrderUpdatePulsePreferenceService();

    expect(await service.load(), KdsTiming.orderUpdateHighlightDuration.inSeconds);
    expect(await service.load(), 30);
  });

  test('save then load round-trips seconds', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final OrderUpdatePulsePreferenceService service =
        OrderUpdatePulsePreferenceService();

    await service.save(45);
    expect(await service.load(), 45);
  });

  test('load clamps stored values outside 5..120', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      OrderUpdatePulsePreferenceService.prefsKey: 1,
    });
    expect(await OrderUpdatePulsePreferenceService().load(), 5);

    SharedPreferences.setMockInitialValues(<String, Object>{
      OrderUpdatePulsePreferenceService.prefsKey: 999,
    });
    expect(await OrderUpdatePulsePreferenceService().load(), 120);
  });
}
