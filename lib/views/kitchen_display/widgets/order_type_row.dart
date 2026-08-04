import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../models/order_model.dart';

class OrderTypeRow extends StatelessWidget {
  const OrderTypeRow({
    super.key,
    required this.type,
    this.tableNumber,
    this.customerName,
  });

  final OrderType type;
  final String? tableNumber;
  final String? customerName;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String detailLabel = switch (type) {
      OrderType.dineIn => 'Table - ${tableNumber ?? '--'}',
      OrderType.delivery => 'Delivery',
      OrderType.takeOut => 'Take-Out',
    };
    final IconData personIcon = switch (type) {
      OrderType.delivery => Icons.two_wheeler,
      OrderType.dineIn || OrderType.takeOut => Icons.person,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.unit + 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colors.outline)),
      ),
      child: Row(
        children: [
          OrderTypeBadge(label: detailLabel),
          const Spacer(),
          if (customerName != null) ...[
            Icon(personIcon, size: 14, color: colors.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                customerName!,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OrderTypeBadge extends StatelessWidget {
  const OrderTypeBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
