class ServerConfig {
  const ServerConfig({required this.ipAddress, required this.port});

  final String ipAddress;
  final String port;

  String get hostPort => '$ipAddress:$port';

  String get baseUrl => 'http://$ipAddress:$port';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ipAddress': ipAddress,
      'port': port,
    };
  }

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      ipAddress: json['ipAddress'] as String,
      port: json['port'] as String,
    );
  }
}
