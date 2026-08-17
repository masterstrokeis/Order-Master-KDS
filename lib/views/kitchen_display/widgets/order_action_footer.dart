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
    required this.onClear,
    this.staleLeftover = false,
  });

  final OrderStatus status;
  final Color accentColor;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onRollback;
  final VoidCallback onClear;
  final bool staleLeftover;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.touchTargetMin,
      width: double.infinity,
      child: staleLeftover
          ? _outlined(
              label: 'Clear',
              foreground: Theme.of(context).colorScheme.onSurface,
              border: Theme.of(context).colorScheme.outline,
              onPressed: onClear,
            )
          : switch (status) {
              OrderStatus.newOrder => _outlined(
                label: 'Start',
                foreground: accentColor,
                border: accentColor,
                onPressed: onStart,
              ),
              // Cooking keeps a same-height actionable Complete control so tickets
              // stay visible after Start until manually completed.
              OrderStatus.cooking => _outlined(
                label: 'Complete',
                foreground: accentColor,
                border: accentColor,
                onPressed: onComplete,
              ),
              // Durable recovery for accidental Complete — neutral outline, not critical red.
              OrderStatus.completed => _outlined(
                label: 'Roll back',
                foreground: AppColors.statusCompleted,
                border: AppColors.statusCompleted,
                onPressed: onRollback,
              ),
              // Cancelled: no Start/Complete (§4a). Same reserved height as other states.
              OrderStatus.cancelled => _outlined(
                label: 'Cancelled',
                foreground: AppColors.statusCancelled,
                border: AppColors.statusCancelled,
                onPressed: null,
              ),
            },
    );
  }

  Widget _outlined({
    required String label,
    required Color foreground,
    required Color border,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        disabledForegroundColor: foreground,
        side: BorderSide(color: border, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.defaultRadius),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
