import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'providers/providers.dart';
import 'services/theme_preference_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts are bundled under assets/google_fonts/ — skip HTTP fetches.
  GoogleFonts.config.allowRuntimeFetching = false;

  final ThemePreferenceService themeService = ThemePreferenceService();
  final ThemeMode initialTheme = await themeService.load();

  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((Ref ref) => initialTheme),
      ],
      child: const OrderMasterApp(),
    ),
  );
}
