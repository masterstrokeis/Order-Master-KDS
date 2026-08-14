import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/order_column_packer.dart';
import '../../../models/order_item_model.dart';
import '../../../models/order_model.dart';
import '../../../models/urgency_settings.dart';
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
  Color warningColor = AppColors.urgencyWarning,
  Color criticalColor = AppColors.urgencyCritical,
}) {
  // Cancelled uses its own muted token — never urgency red (§4a confirmed).
  if (status == OrderStatus.cancelled) {
    return AppColors.statusCancelled;
  }
  if (urgency == OrderUrgency.critical) {
    return criticalColor;
  }
  if (urgency == OrderUrgency.warning) {
    return warningColor;
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
    final Color warningColor = ref.watch(
      urgencySettingsProvider.select(
        (UrgencySettings settings) => settings.warningColor,
      ),
    );
    final Color criticalColor = ref.watch(
      urgencySettingsProvider.select(
        (UrgencySettings settings) => settings.criticalColor,
      ),
    );
    final Color accent = headerColorFor(
      status: order.status,
      urgency: urgency,
      brightness: Theme.of(context).brightness,
      warningColor: warningColor,
      criticalColor: criticalColor,
    );
    final DateTime? pulseUntil = ref.watch(
      orderUpdatePulseUntilProvider.select(
        (Map<String, DateTime> untils) => untils[segment.orderId],
      ),
    );
    final List<OrderItem> items = segment.itemsFor(order);

    return _OrderUpdatePulse(
      orderId: segment.orderId,
      pulseUntil: pulseUntil,
      builder: (BuildContext context, double pulseT) {
        final Color headerAccent = pulseT == 0
            ? accent
            : Color.lerp(accent, AppColors.orderUpdatePulse, pulseT * 0.5)!;
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
                    headerColor: headerAccent,
                  ),
                if (segment.isPrimary)
                  OrderTypeRow(
                    type: order.type,
                    tableNumber: order.tableNumber,
                    customerName: order.customerName,
                  ),
                if (segment.showIncomingContinued)
                  const ContinuedLabel(
                    direction: ContinuedLabelDirection.incoming,
                  ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.unit + 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OrderItemList(
                        items: items,
                        orderStatus: order.status,
                        onToggleItem: (String itemId) {
                          ref
                              .read(orderControllerProvider.notifier)
                              .toggleItemCompleted(order.id, itemId);
                        },
                        onAcknowledgeRemoved: (String itemId) {
                          ref
                              .read(orderControllerProvider.notifier)
                              .acknowledgeRemovedItem(order.id, itemId);
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
                          onStart: () =>
                              ref.read(orderControllerProvider.notifier).startOrder(order.id),
                          onComplete: () =>
                              ref.read(orderControllerProvider.notifier).completeOrder(order.id),
                          onRollback: () =>
                              ref.read(orderControllerProvider.notifier).rollbackOrder(order.id),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrderUpdatePulse extends StatefulWidget {
  const _OrderUpdatePulse({
    required this.orderId,
    required this.pulseUntil,
    required this.builder,
  });

  final String orderId;
  final DateTime? pulseUntil;
  final Widget Function(BuildContext context, double pulseT) builder;

  @override
  State<_OrderUpdatePulse> createState() => _OrderUpdatePulseState();
}

class _OrderUpdatePulseState extends State<_OrderUpdatePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _expiry;

  bool get _active {
    final DateTime? until = widget.pulseUntil;
    if (until == null) {
      return false;
    }
    return until.isAfter(DateTime.now().toUtc());
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(_OrderUpdatePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulseUntil != widget.pulseUntil) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    _expiry?.cancel();
    if (!_active) {
      _controller.stop();
      _controller.value = 0;
      return;
    }
    _controller.repeat(reverse: true);
    final Duration remaining = widget.pulseUntil!.difference(
      DateTime.now().toUtc(),
    );
    if (remaining <= Duration.zero) {
      return;
    }
    _expiry = Timer(remaining, () {
      if (!mounted) {
        return;
      }
      _controller.stop();
      _controller.value = 0;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _expiry?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final bool pulsing = _active;
        final double pulseT = pulsing ? 0.45 + (0.55 * _controller.value) : 0;
        return DecoratedBox(
          key: Key('order-update-pulse-${widget.orderId}'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: pulsing
                ? Border.all(
                    color: AppColors.orderUpdatePulse.withValues(alpha: pulseT),
                    width: 3,
                  )
                : Border.all(color: Colors.transparent, width: 3),
          ),
          child: widget.builder(context, pulseT),
        );
      },
    );
  }
}

/// Continuation cards share [OrderCard] rendering; kept as a named alias for
/// screen inventory clarity from the plan.
typedef ContinuationCard = OrderCard;
