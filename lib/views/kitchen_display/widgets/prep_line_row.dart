import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/order_type_display.dart';
import '../prep_line.dart';

class PrepLineRow extends StatelessWidget {
  const PrepLineRow({super.key, required this.line});

  final PrepLine line;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextStyle? body = Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.unit + 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppSpacing.touchTargetMin / 2,
            child: Text(
              '${line.quantity}',
              style: body?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppSpacing.unit),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.productName,
                  style: body?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.unit / 2),
                Wrap(
                  spacing: AppSpacing.unit,
                  runSpacing: AppSpacing.unit / 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _OrderContext(
                      icon: orderTypePrepIcon(line.orderType),
                      label: 'Order #${line.displayNumber}',
                    ),
                    Text(
                      line.serviceLabel,
                      style: body?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatTime(line.createdAt),
                      style: body?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (line.customerName != null &&
                    line.customerName!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.unit / 2),
                  _OrderContext(
                    icon: Icons.person_outline,
                    label: line.customerName!,
                  ),
                ],
                if (line.modifierText != null &&
                    line.modifierText!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.unit / 2),
                  Text(
                    line.modifierText!,
                    style: body?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (line.note != null && line.note!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.unit / 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Note: ',
                          style: body?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: line.note,
                          style: body?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
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

class _OrderContext extends StatelessWidget {
  const _OrderContext({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSpacing.gutter, color: color),
        const SizedBox(width: AppSpacing.unit / 2),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: color, fontSize: 12),
        ),
      ],
    );
  }
}
