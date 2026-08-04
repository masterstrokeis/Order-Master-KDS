import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'dark_mode_toggle.dart';
import 'order_status_tabs.dart';
import 'station_selector.dart';
import 'user_avatar.dart';

class KdsTopBar extends StatelessWidget {
  const KdsTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.chromeHeader,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.pageMargin,
          vertical: AppSpacing.unit + 4,
        ),
        child: Row(
          children: [
            _BrandLabel(),
            SizedBox(width: AppSpacing.pageMargin),
            StationSelector(),
            Spacer(),
            OrderStatusTabs(),
            Spacer(),
            DarkModeToggle(),
            SizedBox(width: AppSpacing.pageMargin),
            UserAvatar(),
          ],
        ),
      ),
    );
  }
}

class _BrandLabel extends StatelessWidget {
  const _BrandLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      'La Botica',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: AppColors.onStatusHeader,
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
    );
  }
}
