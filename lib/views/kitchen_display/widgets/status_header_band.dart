import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/order_type_display.dart';
import '../../../models/order_model.dart';

class StatusHeaderBand extends StatelessWidget {
  const StatusHeaderBand({
    super.key,
    required this.displayNumber,
    required this.createdAt,
    required this.orderType,
    required this.headerColor,
    this.status = OrderStatus.newOrder,
  });

  final String displayNumber;
  final DateTime createdAt;
  final OrderType orderType;
  final OrderStatus status;
  final Color headerColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      color: headerColor,
      padding: const EdgeInsets.all(AppSpacing.unit + 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status == OrderStatus.cancelled
                      ? 'Cancelled #$displayNumber'
                      : 'Order #$displayNumber',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onStatusHeader,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(createdAt),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onStatusHeader.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (status == OrderStatus.cancelled)
            Text(
              'Cancelled',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onStatusHeader,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            )
          else
            OrderTypeHeaderIndicator(orderType: orderType),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final int hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final String minute = time.minute.toString().padLeft(2, '0');
    final String period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class OrderTypeHeaderIndicator extends StatelessWidget {
  const OrderTypeHeaderIndicator({super.key, required this.orderType});

  final OrderType orderType;

  @override
  Widget build(BuildContext context) {
    final IconData icon = orderTypeHeaderIcon(orderType);
    final String label = orderType.displayLabel;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.unit,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.onStatusHeader.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.onStatusHeader),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onStatusHeader,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
