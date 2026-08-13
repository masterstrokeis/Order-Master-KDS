import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/kds_layout.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/order_column_packer.dart';
import '../../../models/order_item_model.dart';
import '../../../models/order_model.dart';
import '../../../providers/providers.dart';

Future<void> showWaitingOrdersPanel({
  required BuildContext context,
  required BoardLayoutConstraints constraints,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close waiting orders',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          final double tokenWidth =
              KdsLayout.minimumColumnWidth + AppSpacing.pageMargin * 2;
          final double panelWidth = tokenWidth.clamp(
            0,
            MediaQuery.sizeOf(dialogContext).width,
          );

          return Align(
            alignment: Alignment.centerRight,
            child: SafeArea(
              child: SizedBox(
                width: panelWidth,
                height: double.infinity,
                child: WaitingOrdersPanel(constraints: constraints),
              ),
            ),
          );
        },
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          final Animation<Offset> position =
              Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: position, child: child),
          );
        },
  );
}

class WaitingOrdersPanel extends ConsumerWidget {
  const WaitingOrdersPanel({super.key, required this.constraints});

  final BoardLayoutConstraints constraints;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PackedOrderBoard packed = ref.watch(
      packedOrderBoardProvider(constraints),
    );
    final List<Order> visible = ref.watch(ordersForCurrentViewProvider);
    final Map<String, Order> byId = <String, Order>{
      for (final Order order in visible) order.id: order,
    };
    final List<Order> waiting = packed.unplacedOrderIds
        .map((String id) => byId[id])
        .whereType<Order>()
        .toList()
      ..sort((Order a, Order b) => a.createdAt.compareTo(b.createdAt));

    final ColorScheme colors = Theme.of(context).colorScheme;
    final DateTime now = ref.watch(kdsClockProvider).value ?? DateTime.now();

    return Semantics(
      namesRoute: true,
      label: 'Waiting orders',
      child: Material(
        color: colors.surface,
        elevation: AppSpacing.unit,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadii.lg),
            bottomLeft: Radius.circular(AppRadii.lg),
          ),
          side: BorderSide(color: colors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.pageMargin,
                top: AppSpacing.gutter,
                right: AppSpacing.unit,
                bottom: AppSpacing.gutter,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Waiting orders',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.unit / 2),
                        Text(
                          '${waiting.length} waiting',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    autofocus: true,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.outline),
            Expanded(
              child: waiting.isEmpty
                  ? const _NothingWaiting()
                  : ListView.separated(
                      key: const ValueKey<String>('waiting-orders-list'),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.unit,
                      ),
                      itemCount: waiting.length,
                      separatorBuilder: (BuildContext context, int index) {
                        return Divider(
                          height: 1,
                          indent: AppSpacing.gutter,
                          endIndent: AppSpacing.gutter,
                          color: colors.outlineVariant,
                        );
                      },
                      itemBuilder: (BuildContext context, int index) {
                        final Order order = waiting[index];
                        return _WaitingOrderTile(
                          key: ValueKey<String>(order.id),
                          order: order,
                          now: now,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingOrderTile extends StatelessWidget {
  const _WaitingOrderTile({
    super.key,
    required this.order,
    required this.now,
  });

  final Order order;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextStyle? body = Theme.of(context).textTheme.bodyMedium;
    final int itemCount = order.items.length;
    final String typeLabel = _typeLabel(order);
    final String elapsed = _formatElapsed(now.difference(order.createdAt));

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.unit / 2,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.gutter,
        ),
        title: Text(
          'Order #${order.displayNumber}',
          style: body?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.unit / 2),
          child: Wrap(
            spacing: AppSpacing.unit,
            runSpacing: AppSpacing.unit / 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                typeLabel,
                style: body?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$itemCount item${itemCount == 1 ? '' : 's'}',
                style: body?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              Text(
                elapsed,
                style: body?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        children: [
          for (final OrderItem item in order.items) ...[
            _ReadOnlyItemRow(item: item),
            if (item != order.items.last)
              const SizedBox(height: AppSpacing.unit),
          ],
        ],
      ),
    );
  }

  String _typeLabel(Order order) {
    return switch (order.type) {
      OrderType.dineIn => 'Table - ${order.tableNumber ?? '--'}',
      OrderType.delivery => 'Delivery',
      OrderType.takeOut => 'Take-Out',
    };
  }

  String _formatElapsed(Duration elapsed) {
    if (elapsed.isNegative) {
      return '0m';
    }
    if (elapsed.inMinutes < 1) {
      return '<1m';
    }
    if (elapsed.inHours < 1) {
      return '${elapsed.inMinutes}m';
    }
    final int hours = elapsed.inHours;
    final int minutes = elapsed.inMinutes % 60;
    if (minutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${minutes}m';
  }
}

class _ReadOnlyItemRow extends StatelessWidget {
  const _ReadOnlyItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextStyle? body = Theme.of(context).textTheme.bodyMedium;
    final Color nameColor = item.isRemoved
        ? colors.onSurfaceVariant
        : colors.onSurface;
    final String name = item.isRemoved
        ? 'Removed · ${item.nameSnapshot}'
        : item.nameSnapshot;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppSpacing.touchTargetMin / 2,
          child: Text(
            '${item.quantity}',
            style: body?.copyWith(
              fontWeight: FontWeight.w700,
              color: item.isRemoved ? colors.onSurfaceVariant : null,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.unit),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: body?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: nameColor,
                  decoration: item.isRemoved || item.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                  fontStyle: item.isRemoved ? FontStyle.italic : null,
                ),
              ),
              if (item.modifierText != null && item.modifierText!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    item.modifierText!,
                    style: body?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (item.note != null && item.note!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text.rich(
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
                          text: item.note,
                          style: body?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
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
  }
}

class _NothingWaiting extends StatelessWidget {
  const _NothingWaiting();

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: color),
            const SizedBox(height: AppSpacing.unit),
            Text(
              'Nothing waiting',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
