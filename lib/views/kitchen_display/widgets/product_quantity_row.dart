import 'package:flutter/material.dart';

import '../../../core/constants/kds_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

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
    this.modifierText,
    this.numberBadge,
    this.onTap,
  });

  final String name;
  final String? modifierText;
  final int quantity;
  final int? numberBadge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = quantity > 0 && onTap != null;
    final String semanticsLabel = modifierText == null || modifierText!.isEmpty
        ? '$name, quantity $quantity'
        : '$name, $modifierText, quantity $quantity';

    return Semantics(
      button: isEnabled,
      enabled: isEnabled,
      label: semanticsLabel,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (numberBadge != null) ...[
                  SizedBox(
                    width: KdsLayout.itemBadgeColumnWidth,
                    child: Text(
                      '$numberBadge',
                      key: Key('group-number-badge-$numberBadge'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelCaps.copyWith(
                        color: AppColors.keyboardFocus,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: KdsLayout.itemTextGap),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isEnabled
                              ? AppColors.chromeOnSurface
                              : AppColors.chromeOnSurfaceDim,
                          fontSize: 14,
                        ),
                      ),
                      if (modifierText != null && modifierText!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          modifierText!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.chromeOnSurfaceDim,
                                fontSize: 12,
                              ),
                        ),
                      ],
                    ],
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
