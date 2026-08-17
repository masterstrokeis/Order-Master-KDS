import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:order_master_kds/models/kds_api_error.dart';
import 'package:order_master_kds/models/kds_connection_failure.dart';
import 'package:order_master_kds/services/kds_http_client.dart';

void main() {
  test('retries once after 401 when onUnauthorized returns a new token', () async {
    int calls = 0;
    final List<String?> authHeaders = <String?>[];

    final MockClient mock = MockClient((http.Request request) async {
      calls++;
      authHeaders.add(request.headers['Authorization']);
      if (calls == 1) {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'error': <String, dynamic>{
              'code': 'UNAUTHORIZED',
              'message': 'Token expired',
            },
          }),
          401,
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{
          'serverTime': '2026-08-08T12:00:00Z',
          'ok': true,
        }),
        200,
      );
    });

    int refreshCalls = 0;
    final KdsHttpClient client = KdsHttpClient(
      client: mock,
      baseUrl: 'http://localhost:5012',
      onUnauthorized: () async {
        refreshCalls++;
        return 'new-access-token';
      },
    );

    final Map<String, dynamic> result = await client.getJson(
      '/orders',
      accessToken: 'stale-token',
      deviceId: 'device-1',
      query: <String, String>{'stationId': 'station_grill'},
    );

    expect(result['ok'], isTrue);
    expect(calls, 2);
    expect(refreshCalls, 1);
    expect(authHeaders[0], 'Bearer stale-token');
    expect(authHeaders[1], 'Bearer new-access-token');
  });

  test('does not retry when onUnauthorized returns null', () async {
    int calls = 0;
    final MockClient mock = MockClient((http.Request request) async {
      calls++;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'error': <String, dynamic>{
            'code': 'UNAUTHORIZED',
            'message': 'Token expired',
          },
        }),
        401,
      );
    });

    final KdsHttpClient client = KdsHttpClient(
      client: mock,
      baseUrl: 'http://localhost:5012',
      onUnauthorized: () async => null,
    );

    await expectLater(
      () => client.getJson(
        '/orders',
        accessToken: 'stale-token',
        deviceId: 'device-1',
      ),
      throwsA(
        isA<KdsApiError>().having(
          (KdsApiError e) => e.code,
          'code',
          'UNAUTHORIZED',
        ),
      ),
    );
    expect(calls, 1);
  });

  test('unauthenticated posts do not invoke onUnauthorized on 401', () async {
    int refreshCalls = 0;
    final MockClient mock = MockClient((http.Request request) async {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'error': <String, dynamic>{
            'code': 'INVALID_PIN',
            'message': 'Invalid PIN.',
          },
        }),
        401,
      );
    });

    final KdsHttpClient client = KdsHttpClient(
      client: mock,
      baseUrl: 'http://localhost:5012',
      onUnauthorized: () async {
        refreshCalls++;
        return 'should-not-be-used';
      },
    );

    await expectLater(
      () => client.postJson(
        '/auth/login',
        body: <String, dynamic>{'pin': '0000'},
      ),
      throwsA(isA<KdsApiError>()),
    );
    expect(refreshCalls, 0);
  });

  test('times out with KdsConnectionFailure within the configured window',
      () async {
    final MockClient mock = MockClient((http.Request request) async {
      await Future<void>.delayed(const Duration(seconds: 5));
      return http.Response('{}', 200);
    });

    final KdsHttpClient client = KdsHttpClient(
      client: mock,
      baseUrl: 'http://192.168.99.99:5012',
      requestTimeout: const Duration(milliseconds: 50),
    );

    final Stopwatch watch = Stopwatch()..start();
    await expectLater(
      () => client.postJson(
        '/auth/login',
        body: <String, dynamic>{'pin': '123', 'deviceId': 'device-1'},
      ),
      throwsA(isA<KdsConnectionFailure>()),
    );
    watch.stop();

    expect(watch.elapsedMilliseconds, lessThan(2000));
  });
}
