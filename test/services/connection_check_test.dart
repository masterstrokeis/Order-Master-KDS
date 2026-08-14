import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:order_master_kds/services/connection_check.dart';

void main() {
  test('200 with status ok is success', () async {
    final MockClient client = MockClient((http.Request request) async {
      expect(
        request.url.toString(),
        'http://192.168.1.100:8000/api/v1/kds/connectionCheck',
      );
      return http.Response(
        '{"status":"ok","timestamp":"2026-08-14T09:26:35Z"}',
        200,
      );
    });

    final ConnectionCheckResult result = await checkKdsConnection(
      baseUrl: 'http://192.168.1.100:8000',
      client: client,
    );
    expect(result.ok, isTrue);
  });

  test('non-200 does not succeed', () async {
    final MockClient client = MockClient((http.Request request) async {
      return http.Response('nope', 500);
    });

    final ConnectionCheckResult result = await checkKdsConnection(
      baseUrl: 'http://192.168.1.100:8000',
      client: client,
    );
    expect(result.ok, isFalse);
    expect(result.errorMessage, isNotEmpty);
  });

  test('200 without status ok does not succeed', () async {
    final MockClient client = MockClient((http.Request request) async {
      return http.Response('{"status":"down"}', 200);
    });

    final ConnectionCheckResult result = await checkKdsConnection(
      baseUrl: 'http://192.168.1.100:8000',
      client: client,
    );
    expect(result.ok, isFalse);
  });
}
