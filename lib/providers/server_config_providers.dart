import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/constants/kds_config.dart';
import '../models/server_config.dart';
import '../services/server_config_service.dart';

final Provider<ServerConfigService> serverConfigServiceProvider =
    Provider<ServerConfigService>((Ref ref) => ServerConfigService());

final StateProvider<ServerConfig?> serverConfigProvider =
    StateProvider<ServerConfig?>((Ref ref) => null);

final Provider<String> kdsBaseUrlProvider = Provider<String>((Ref ref) {
  return ref.watch(serverConfigProvider)?.baseUrl ?? KdsConfig.baseUrl;
});
