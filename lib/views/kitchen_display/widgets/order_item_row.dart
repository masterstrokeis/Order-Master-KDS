import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../models/order_item_model.dart';
import '../../../models/order_model.dart';

class OrderItemList extends StatelessWidget {
  const OrderItemList({
    super.key,
    required this.items,
    required this.orderStatus,
    required this.onToggleItem,
  });

  final List<OrderItem> items;
  final OrderStatus orderStatus;
  final void Function(String itemId) onToggleItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final OrderItem item in items) ...[
          OrderItemRow(
            item: item,
            canToggle: orderStatus == OrderStatus.cooking,
            onDoubleTap: () => onToggleItem(item.id),
          ),
          const SizedBox(height: AppSpacing.gutter),
        ],
      ],
    );
  }
}

class OrderItemRow extends StatelessWidget {
  const OrderItemRow({
    super.key,
    required this.item,
    required this.canToggle,
    required this.onDoubleTap,
  });

  final OrderItem item;
  final bool canToggle;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextStyle? base = Theme.of(context).textTheme.bodyMedium;
    final bool struck = item.isCompleted;
    // Explicit decorationColor so line-through paints on muted secondary text
    // (Flutter can skip the decoration when color is left implicit).
    final TextDecoration? decoration = struck
        ? TextDecoration.lineThrough
        : null;

    TextStyle? withStrike(TextStyle? style, Color decorationColor) {
      if (!struck || style == null) {
        return style;
      }
      return style.copyWith(
        decoration: decoration,
        decorationColor: decorationColor,
      );
    }

    final Color nameColor = colors.onSurface;
    final Color secondaryColor = colors.onSurfaceVariant;

    final Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          child: Text(
            '${item.quantity}',
            style: base?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: AppSpacing.unit + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.nameSnapshot,
                style: withStrike(
                  base?.copyWith(
                    color: nameColor,
                    fontWeight: FontWeight.w600,
                  ),
                  nameColor,
                ),
              ),
              if (item.modifierText != null && item.modifierText!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    item.modifierText!,
                    style: withStrike(
                      base?.copyWith(
                        color: secondaryColor,
                        fontSize: 12,
                      ),
                      secondaryColor,
                    ),
                  ),
                ),
              if (item.note != null && item.note!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text.rich(
                    TextSpan(
                      style: withStrike(
                        base?.copyWith(fontSize: 12),
                        secondaryColor,
                      ),
                      children: [
                        TextSpan(
                          text: 'Note: ',
                          style: withStrike(
                            base?.copyWith(
                              color: nameColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            nameColor,
                          ),
                        ),
                        TextSpan(
                          text: item.note,
                          style: withStrike(
                            base?.copyWith(
                              color: secondaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                            secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    if (!canToggle) {
      return content;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: onDoubleTap,
      child: content,
    );
  }
}
