import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'models/server_config.dart';
import 'providers/providers.dart';
import 'views/login/login_screen.dart';
import 'views/server_setup/server_setup_screen.dart';

class OrderMasterApp extends ConsumerWidget {
  const OrderMasterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    ref.watch(voiceAnnouncementProvider);
    final ServerConfig? server = ref.watch(serverConfigProvider);

    return MaterialApp(
      title: 'Order Master KDS',
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      themeMode: themeMode,
      home: server == null
          ? const ServerSetupScreen()
          : const LoginScreen(),
    );
  }
}
