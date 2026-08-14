import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'controllers/urgency_settings_controller.dart';
import 'models/server_config.dart';
import 'models/urgency_settings.dart';
import 'providers/providers.dart';
import 'services/announcement_preference_service.dart';
import 'services/order_update_pulse_preference_service.dart';
import 'services/product_quantity_list_preference_service.dart';
import 'services/server_config_service.dart';
import 'services/theme_preference_service.dart';
import 'services/urgency_settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Fonts are bundled under assets/google_fonts/ — skip HTTP fetches.
  GoogleFonts.config.allowRuntimeFetching = false;

  final ThemePreferenceService themeService = ThemePreferenceService();
  final ThemeMode initialTheme = await themeService.load();

  final UrgencySettingsService urgencyService = UrgencySettingsService();
  final UrgencySettings initialUrgency = await urgencyService.load();

  final AnnouncementPreferenceService announcementService =
      AnnouncementPreferenceService();
  final bool initialAnnouncementsEnabled = await announcementService.load();

  final OrderUpdatePulsePreferenceService pulseService =
      OrderUpdatePulsePreferenceService();
  final int initialPulseSeconds = await pulseService.load();

  final CancelledDisplayPreferenceService cancelledDisplayService =
      CancelledDisplayPreferenceService();
  final int initialCancelledDisplaySeconds =
      await cancelledDisplayService.load();

  final ServerConfigService serverConfigService = ServerConfigService();
  final ServerConfig? initialServer = await serverConfigService.load();

  final ProductQuantityListPreferenceService productQuantityListService =
      ProductQuantityListPreferenceService();
  final bool initialProductQuantityListVisible =
      await productQuantityListService.load();

  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((Ref ref) => initialTheme),
        announcementsEnabledProvider.overrideWith(
          (Ref ref) => initialAnnouncementsEnabled,
        ),
        productQuantityListVisibleProvider.overrideWith(
          (Ref ref) => initialProductQuantityListVisible,
        ),
        orderUpdatePulseSecondsProvider.overrideWith(
          (Ref ref) => initialPulseSeconds,
        ),
        cancelledDisplaySecondsProvider.overrideWith(
          (Ref ref) => initialCancelledDisplaySeconds,
        ),
        serverConfigProvider.overrideWith((Ref ref) => initialServer),
        urgencySettingsServiceProvider.overrideWith(
          (Ref ref) => urgencyService,
        ),
        urgencySettingsProvider.overrideWith(
          () => UrgencySettingsController(initialUrgency),
        ),
      ],
      child: const OrderMasterApp(),
    ),
  );
}
