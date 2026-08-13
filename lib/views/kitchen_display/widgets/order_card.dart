import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/order_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/order_column_packer.dart';
import '../../../models/order_item_model.dart';
import '../../../models/order_model.dart';
import '../../../providers/providers.dart';
import 'continued_label.dart';
import 'order_action_footer.dart';
import 'order_item_row.dart';
import 'order_type_row.dart';
import 'status_header_band.dart';

Color headerColorFor({
  required OrderStatus status,
  required OrderUrgency urgency,
  required Brightness brightness,
}) {
  // Cancelled uses its own muted token — never urgency red (§4a confirmed).
  if (status == OrderStatus.cancelled) {
    return AppColors.statusCancelled;
  }
  if (urgency == OrderUrgency.critical) {
    return AppColors.urgencyCritical;
  }
  if (urgency == OrderUrgency.warning) {
    return AppColors.urgencyWarning;
  }
  return switch (status) {
    OrderStatus.newOrder => brightness == Brightness.dark
        ? AppColors.statusNewOnDark
        : AppColors.statusNew,
    OrderStatus.cooking => AppColors.statusCooking,
    OrderStatus.completed => AppColors.statusCompleted,
    OrderStatus.cancelled => AppColors.statusCancelled,
  };
}

class OrderCard extends ConsumerWidget {
  const OrderCard({super.key, required this.segment});

  final CardSegment segment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Order? order = ref.watch(orderByIdProvider(segment.orderId));
    if (order == null) {
      return const SizedBox.shrink();
    }

    final OrderUrgency urgency = ref.watch(
      orderUrgencyProvider(segment.orderId),
    );
    final Color accent = headerColorFor(
      status: order.status,
      urgency: urgency,
      brightness: Theme.of(context).brightness,
    );
    final List<OrderItem> items = segment.itemsFor(order);
    final OrderController controller = ref.read(
      orderControllerProvider.notifier,
    );

    return Material(
      key: ValueKey<String>('${segment.orderId}:${segment.segmentIndex}'),
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // TODO: define card tap behavior (order detail / bump).
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (segment.isPrimary)
              StatusHeaderBand(
                displayNumber: order.displayNumber,
                createdAt: order.createdAt,
                orderType: order.type,
                status: order.status,
                headerColor: accent,
              ),
            if (segment.isPrimary)
              OrderTypeRow(
                type: order.type,
                tableNumber: order.tableNumber,
                customerName: order.customerName,
              ),
            if (segment.showIncomingContinued)
              const ContinuedLabel(direction: ContinuedLabelDirection.incoming),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.unit + 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OrderItemList(
                    items: items,
                    orderStatus: order.status,
                    onToggleItem: (String itemId) {
                      controller.toggleItemCompleted(order.id, itemId);
                    },
                    onAcknowledgeRemoved: (String itemId) {
                      controller.acknowledgeRemovedItem(order.id, itemId);
                    },
                  ),
                  if (segment.showOutgoingContinued)
                    const ContinuedLabel(
                      direction: ContinuedLabelDirection.outgoing,
                    ),
                  if (segment.isFinal) ...[
                    const SizedBox(height: AppSpacing.unit),
                    OrderActionFooter(
                      status: order.status,
                      accentColor: accent,
                      onStart: () => controller.startOrder(order.id),
                      onComplete: () => controller.completeOrder(order.id),
                      onRollback: () => controller.rollbackOrder(order.id),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Continuation cards share [OrderCard] rendering; kept as a named alias for
/// screen inventory clarity from the plan.
typedef ContinuationCard = OrderCard;
