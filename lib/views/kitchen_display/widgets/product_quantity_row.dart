import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';

class QtyBadge extends StatelessWidget {
  const QtyBadge({super.key, required this.quantity});

  final int quantity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.unit,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.chromeBadgeBackground,
        borderRadius: BorderRadius.circular(AppRadii.defaultRadius),
      ),
      child: Text(
        '$quantity',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.chromeOnSurface,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ProductQuantityRow extends StatelessWidget {
  const ProductQuantityRow({
    super.key,
    required this.name,
    required this.quantity,
    this.onTap,
  });

  final String name;
  final int quantity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = quantity > 0 && onTap != null;

    return Semantics(
      button: isEnabled,
      enabled: isEnabled,
      label: '$name, quantity $quantity',
      hint: isEnabled ? 'Show contributing orders' : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          hoverColor: AppColors.chromeBorder,
          focusColor: AppColors.chromeBorder,
          borderRadius: BorderRadius.circular(AppRadii.defaultRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gutter,
              vertical: AppSpacing.unit,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isEnabled
                          ? AppColors.chromeOnSurface
                          : AppColors.chromeOnSurfaceDim,
                      fontSize: 14,
                    ),
                  ),
                ),
                QtyBadge(quantity: quantity),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
