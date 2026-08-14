import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/utils/server_address.dart';

void main() {
  group('validateServerAddress', () {
    test('accepts a typical LAN host and port', () {
      expect(
        validateServerAddress(ipAddress: '192.168.1.100', port: '8000'),
        isNull,
      );
    });

    test('rejects an invalid IP', () {
      expect(
        validateServerAddress(ipAddress: '192.168.1', port: '8000'),
        'Enter a valid IPv4 address.',
      );
      expect(
        validateServerAddress(ipAddress: '999.0.0.1', port: '8000'),
        'Enter a valid IPv4 address.',
      );
    });

    test('rejects an invalid port', () {
      expect(
        validateServerAddress(ipAddress: '192.168.1.100', port: '0'),
        'Enter a port between 1 and 65535.',
      );
      expect(
        validateServerAddress(ipAddress: '192.168.1.100', port: '99999'),
        'Enter a port between 1 and 65535.',
      );
    });
  });

  group('parseServerQrPayload', () {
    test('reads ip_address and port_number strings', () {
      final ({String ipAddress, String port})? parsed = parseServerQrPayload(
        '{"ip_address":"192.168.1.100","port_number":"8000"}',
      );
      expect(parsed?.ipAddress, '192.168.1.100');
      expect(parsed?.port, '8000');
    });

    test('returns null for invalid JSON', () {
      expect(parseServerQrPayload('not-json'), isNull);
    });

    test('returns null when keys are missing', () {
      expect(parseServerQrPayload('{"ip_address":"192.168.1.100"}'), isNull);
      expect(parseServerQrPayload('{"host":"192.168.1.100","port":"8000"}'), isNull);
    });
  });
}
