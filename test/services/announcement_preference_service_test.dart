import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/services/announcement_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load returns true when prefs are empty', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AnnouncementPreferenceService service = AnnouncementPreferenceService();

    expect(await service.load(), isTrue);
  });

  test('load returns a stored false value', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AnnouncementPreferenceService.prefsKey: false,
    });
    final AnnouncementPreferenceService service = AnnouncementPreferenceService();

    expect(await service.load(), isFalse);
  });

  test('save then load round-trips the enabled flag', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AnnouncementPreferenceService service = AnnouncementPreferenceService();

    await service.save(false);
    expect(await service.load(), isFalse);

    await service.save(true);
    expect(await service.load(), isTrue);
  });
}
