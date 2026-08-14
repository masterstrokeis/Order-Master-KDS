import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/services/product_quantity_list_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load returns true when prefs are empty', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProductQuantityListPreferenceService service =
        ProductQuantityListPreferenceService();

    expect(await service.load(), isTrue);
  });

  test('load returns a stored false value', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ProductQuantityListPreferenceService.prefsKey: false,
    });
    final ProductQuantityListPreferenceService service =
        ProductQuantityListPreferenceService();

    expect(await service.load(), isFalse);
  });

  test('save then load round-trips the visible flag', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProductQuantityListPreferenceService service =
        ProductQuantityListPreferenceService();

    await service.save(false);
    expect(await service.load(), isFalse);

    await service.save(true);
    expect(await service.load(), isTrue);
  });
}
