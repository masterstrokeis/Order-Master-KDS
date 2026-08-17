import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/order_item_model.dart';
import '../../../models/order_model.dart';

class OrderItemList extends StatelessWidget {
  const OrderItemList({
    super.key,
    required this.items,
    required this.orderStatus,
    required this.onToggleItem,
    required this.onAcknowledgeRemoved,
    this.allowMutations = true,
  });

  final List<OrderItem> items;
  final OrderStatus orderStatus;
  final void Function(String itemId) onToggleItem;
  final void Function(String itemId) onAcknowledgeRemoved;
  final bool allowMutations;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final OrderItem item in items) ...[
          OrderItemRow(
            item: item,
            canToggle: allowMutations &&
                orderStatus == OrderStatus.cooking &&
                !item.isRemoved,
            onDoubleTap: () => onToggleItem(item.id),
            onAcknowledgeRemoved: allowMutations
                ? () => onAcknowledgeRemoved(item.id)
                : null,
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
    required this.onAcknowledgeRemoved,
  });

  final OrderItem item;
  final bool canToggle;
  final VoidCallback onDoubleTap;
  final VoidCallback? onAcknowledgeRemoved;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextStyle? base = Theme.of(context).textTheme.bodyMedium;
    final bool struck = item.isCompleted && !item.isRemoved;
    final bool highlightNew = item.isNew && !item.isRemoved;
    final bool highlightRemovedUnseen =
        item.isRemoved && item.isRemovedUnseen;

    final TextDecoration? decoration = struck
        ? TextDecoration.lineThrough
        : (item.isRemoved ? TextDecoration.lineThrough : null);

    TextStyle? withStrike(TextStyle? style, Color decorationColor) {
      if (decoration == null || style == null) {
        return style;
      }
      return style.copyWith(
        decoration: decoration,
        decorationColor: decorationColor,
      );
    }

    final Color nameColor = item.isRemoved
        ? colors.onSurfaceVariant
        : colors.onSurface;
    final Color secondaryColor = colors.onSurfaceVariant;

    final Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          child: Text(
            '${item.quantity}',
            style: base?.copyWith(
              fontWeight: FontWeight.w700,
              color: item.isRemoved ? secondaryColor : null,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.unit + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.isRemoved
                    ? 'Removed · ${item.nameSnapshot}'
                    : item.nameSnapshot,
                style: withStrike(
                  base?.copyWith(
                    color: nameColor,
                    fontWeight: FontWeight.w600,
                    fontStyle: item.isRemoved
                        ? FontStyle.italic
                        : FontStyle.normal,
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
                        AppTextStyles.bodyMd.copyWith(
                          color: nameColor,
                          fontWeight: FontWeight.w700,
                        ),
                        nameColor,
                      ),
                      children: [
                        const TextSpan(text: 'Note: '),
                        TextSpan(text: item.note),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (highlightRemovedUnseen && onAcknowledgeRemoved != null)
          TextButton(
            onPressed: onAcknowledgeRemoved,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(48, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              foregroundColor: AppColors.primaryContainer,
            ),
            child: const Text('Got it'),
          ),
      ],
    );

    final Widget highlighted = DecoratedBox(
      decoration: BoxDecoration(
        color: highlightNew || highlightRemovedUnseen
            ? AppColors.primaryContainer.withValues(alpha: 0.12)
            : null,
        border: highlightNew || highlightRemovedUnseen
            ? const Border(
                left: BorderSide(color: AppColors.primaryContainer, width: 3),
              )
            : null,
      ),
      // No extra left padding — keeps text width (and packing estimates) stable.
      child: content,
    );

    if (!canToggle) {
      return highlighted;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: onDoubleTap,
      child: highlighted,
    );
  }
}
