import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../settings/settings_screen.dart';
import 'order_status_tabs.dart';
import 'station_selector.dart';

class KdsTopBar extends StatelessWidget {
  const KdsTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.chromeHeader,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const _BrandLabel(),
            const SizedBox(width: AppSpacing.pageMargin),
            const StationSelector(),
            const Spacer(),
            const OrderStatusTabs(),
            const Spacer(),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
              icon: const Icon(
                Icons.settings_outlined,
                color: AppColors.onStatusHeader,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandLabel extends ConsumerWidget {
  const _BrandLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String outletName = ref.watch(
      authControllerProvider.select(
        (AuthState state) => state.session?.outlet.name,
      ),
    ) ?? '';

    return Text(
      outletName,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: AppColors.onStatusHeader,
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
    );
  }
}
