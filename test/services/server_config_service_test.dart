import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/models/server_config.dart';
import 'package:order_master_kds/services/server_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load returns null when prefs are empty', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    expect(await ServerConfigService().load(), isNull);
  });

  test('save then load round-trips IP and port', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ServerConfigService service = ServerConfigService();
    const ServerConfig config = ServerConfig(
      ipAddress: '192.168.1.100',
      port: '8000',
    );

    await service.save(config);
    final ServerConfig? loaded = await service.load();

    expect(loaded?.ipAddress, '192.168.1.100');
    expect(loaded?.port, '8000');
    expect(loaded?.baseUrl, 'http://192.168.1.100:8000');
    expect(loaded?.hostPort, '192.168.1.100:8000');
  });
}
