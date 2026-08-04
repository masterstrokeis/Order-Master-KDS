import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';

class BoardOverflowIndicator extends StatelessWidget {
  const BoardOverflowIndicator({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    return Material(
      color: AppColors.lightHeader.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.unit,
        ),
        child: Text(
          '+$count more order${count == 1 ? '' : 's'} waiting',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.onStatusHeader,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
