import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentityService {
  DeviceIdentityService({
    SharedPreferences? preferences,
    Uuid? uuid,
  }) : _preferences = preferences,
       _uuid = uuid ?? const Uuid();

  static const String prefsKey = 'kds_device_id';

  final SharedPreferences? _preferences;
  final Uuid _uuid;

  Future<SharedPreferences> _prefs() async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  /// Returns a stable device id, generating and persisting one on first run.
  Future<String> getOrCreateDeviceId() async {
    final SharedPreferences prefs = await _prefs();
    final String? existing = prefs.getString(prefsKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final String created = _uuid.v4();
    await prefs.setString(prefsKey, created);
    return created;
  }
}
