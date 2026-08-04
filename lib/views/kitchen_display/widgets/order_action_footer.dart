import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/order_model.dart';

class OrderActionFooter extends StatelessWidget {
  const OrderActionFooter({
    super.key,
    required this.status,
    required this.accentColor,
    required this.onStart,
    required this.onComplete,
    required this.onRollback,
  });

  final OrderStatus status;
  final Color accentColor;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onRollback;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.touchTargetMin,
      width: double.infinity,
      child: switch (status) {
        OrderStatus.newOrder => OutlinedButton(
          onPressed: onStart,
          style: OutlinedButton.styleFrom(
            foregroundColor: accentColor,
            side: BorderSide(color: accentColor, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.defaultRadius),
            ),
          ),
          child: const Text(
            'Start',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        // Cooking keeps a same-height actionable Complete control so tickets
        // stay visible after Start until manually completed.
        OrderStatus.cooking => OutlinedButton(
          onPressed: onComplete,
          style: OutlinedButton.styleFrom(
            foregroundColor: accentColor,
            side: BorderSide(color: accentColor, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.defaultRadius),
            ),
          ),
          child: const Text(
            'Complete',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        // Durable recovery for accidental Complete — neutral outline, not critical red.
        OrderStatus.completed => OutlinedButton(
          onPressed: onRollback,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.statusCompleted,
            side: const BorderSide(
              color: AppColors.statusCompleted,
              width: 2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.defaultRadius),
            ),
          ),
          child: const Text(
            'Roll back',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      },
    );
  }
}
