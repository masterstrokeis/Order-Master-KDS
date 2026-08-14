import 'dart:convert';

/// IPv4 + TCP port helpers for the server setup screen.
bool isValidIpv4(String value) {
  final List<String> parts = value.trim().split('.');
  if (parts.length != 4) {
    return false;
  }
  for (final String part in parts) {
    if (part.isEmpty || part.length > 3) {
      return false;
    }
    if (part.length > 1 && part.startsWith('0')) {
      return false;
    }
    final int? octet = int.tryParse(part);
    if (octet == null || octet < 0 || octet > 255) {
      return false;
    }
  }
  return true;
}

bool isValidPort(String value) {
  final int? port = int.tryParse(value.trim());
  return port != null && port >= 1 && port <= 65535;
}

String? validateServerAddress({
  required String ipAddress,
  required String port,
}) {
  if (!isValidIpv4(ipAddress)) {
    return 'Enter a valid IPv4 address.';
  }
  if (!isValidPort(port)) {
    return 'Enter a port between 1 and 65535.';
  }
  return null;
}

/// Parses QR JSON `{ "ip_address": "...", "port_number": "..." }`.
({String ipAddress, String port})? parseServerQrPayload(String raw) {
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    final Object? ip = decoded['ip_address'];
    final Object? port = decoded['port_number'];
    if (ip is! String || port is! String) {
      return null;
    }
    if (ip.trim().isEmpty || port.trim().isEmpty) {
      return null;
    }
    return (ipAddress: ip.trim(), port: port.trim());
  } on Object {
    return null;
  }
}
