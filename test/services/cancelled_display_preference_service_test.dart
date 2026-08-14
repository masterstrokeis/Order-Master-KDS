import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/constants/kds_timing.dart';
import 'package:order_master_kds/services/cancelled_display_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load returns 30 when prefs are empty', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final CancelledDisplayPreferenceService service =
        CancelledDisplayPreferenceService();

    expect(
      await service.load(),
      KdsTiming.cancelledCookingDisplayDuration.inSeconds,
    );
    expect(await service.load(), 30);
  });

  test('save then load round-trips allowed options', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final CancelledDisplayPreferenceService service =
        CancelledDisplayPreferenceService();

    await service.save(15);
    expect(await service.load(), 15);

    await service.save(60);
    expect(await service.load(), 60);

    await service.save(120);
    expect(await service.load(), 120);
  });

  test('load snaps stored values to the nearest option', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      CancelledDisplayPreferenceService.prefsKey: 20,
    });
    expect(await CancelledDisplayPreferenceService().load(), 15);

    SharedPreferences.setMockInitialValues(<String, Object>{
      CancelledDisplayPreferenceService.prefsKey: 50,
    });
    expect(await CancelledDisplayPreferenceService().load(), 60);
  });
}
