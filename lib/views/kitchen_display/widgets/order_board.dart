import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/kds_layout.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/order_column_packer.dart';
import '../../../models/order_model.dart';
import '../../../providers/providers.dart';
import 'board_overflow_indicator.dart';
import 'order_card.dart';
import 'waiting_orders_panel.dart';

class OrderBoard extends ConsumerWidget {
  const OrderBoard({
    super.key,
    required this.boardWidth,
    required this.boardHeight,
  });

  final double boardWidth;
  final double boardHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Order> visibleOrders = ref.watch(ordersForCurrentViewProvider);
    if (visibleOrders.isEmpty) {
      final KdsTab tab = ref.watch(selectedKdsTabProvider);
      final String message = switch (tab) {
        KdsTab.cooking => 'No cooking orders',
        KdsTab.completed => 'No completed orders',
        KdsTab.cancelled => 'No cancelled orders',
      };
      return Center(
        child: Text(
          message,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final PackedOrderBoard packed = ref.watch(
      packedOrderBoardProvider(
        BoardLayoutConstraints(
          boardWidth: boardWidth,
          boardHeight: boardHeight,
        ),
      ),
    );

    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < packed.columns.length; i++) ...[
              if (i > 0) const SizedBox(width: KdsLayout.cardGap),
              SizedBox(
                width: packed.columnWidth,
                height: boardHeight,
                child: _OrderBoardColumn(segments: packed.columns[i]),
              ),
            ],
          ],
        ),
        if (packed.unplacedOrderIds.isNotEmpty)
          Positioned(
            right: AppSpacing.gutter,
            bottom: AppSpacing.gutter,
            child: BoardOverflowIndicator(
              count: packed.unplacedOrderIds.length,
              onTap: () {
                showWaitingOrdersPanel(
                  context: context,
                  constraints: BoardLayoutConstraints(
                    boardWidth: boardWidth,
                    boardHeight: boardHeight,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _OrderBoardColumn extends StatelessWidget {
  const _OrderBoardColumn({required this.segments});

  final List<CardSegment> segments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < segments.length; i++) ...[
          if (i > 0) const SizedBox(height: KdsLayout.cardGap),
          OrderCard(segment: segments[i]),
        ],
      ],
    );
  }
}
