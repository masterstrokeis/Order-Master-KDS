import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/kds_config.dart';

class ConnectionCheckResult {
  const ConnectionCheckResult({required this.ok, this.errorMessage});

  final bool ok;
  final String? errorMessage;
}

/// One-off GET `{baseUrl}/api/v1/kds/connectionCheck`. Does not mutate the live client.
Future<ConnectionCheckResult> checkKdsConnection({
  required String baseUrl,
  http.Client? client,
  Duration timeout = KdsConfig.requestTimeout,
}) async {
  final http.Client httpClient = client ?? http.Client();
  final bool ownsClient = client == null;
  try {
    final Uri uri = Uri.parse('$baseUrl${KdsConfig.apiPrefix}/connectionCheck');
    final http.Response response = await httpClient.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      return const ConnectionCheckResult(
        ok: false,
        errorMessage: 'Could not reach the server. Check IP and port.',
      );
    }
    final Object? decoded = response.body.isEmpty
        ? null
        : jsonDecode(response.body);
    if (decoded is! Map || decoded['status'] != 'ok') {
      return const ConnectionCheckResult(
        ok: false,
        errorMessage: 'Server responded, but the connection check failed.',
      );
    }
    return const ConnectionCheckResult(ok: true);
  } on Object {
    return const ConnectionCheckResult(
      ok: false,
      errorMessage: 'Could not reach the server. Check IP and port.',
    );
  } finally {
    if (ownsClient) {
      httpClient.close();
    }
  }
}
