import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/services/device_identity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists a stable device id across calls', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final DeviceIdentityService service = DeviceIdentityService();

    final String first = await service.getOrCreateDeviceId();
    final String second = await service.getOrCreateDeviceId();

    expect(first, isNotEmpty);
    expect(second, first);
  });

  test('reuses an existing stored device id', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      DeviceIdentityService.prefsKey: 'existing-device-id',
    });
    final DeviceIdentityService service = DeviceIdentityService();

    expect(await service.getOrCreateDeviceId(), 'existing-device-id');
  });
}
