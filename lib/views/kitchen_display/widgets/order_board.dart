import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/kds_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/order_column_packer.dart';
import '../../../models/order_model.dart';
import '../../../providers/providers.dart';
import 'order_card.dart';

class OrderBoard extends ConsumerStatefulWidget {
  const OrderBoard({
    super.key,
    required this.boardWidth,
    required this.boardHeight,
  });

  final double boardWidth;
  final double boardHeight;

  @override
  ConsumerState<OrderBoard> createState() => _OrderBoardState();
}

class _OrderBoardState extends ConsumerState<OrderBoard> {
  static const double _edgeEpsilon = 8;

  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  int _lastColumnCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncEdgeVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncEdgeVisibility());
  }

  @override
  void didUpdateWidget(OrderBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncEdgeVisibility());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_syncEdgeVisibility);
    _scrollController.dispose();
    super.dispose();
  }

  void _syncEdgeVisibility() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    final double offset = _scrollController.offset;
    final double max = _scrollController.position.maxScrollExtent;
    final bool canLeft = offset > _edgeEpsilon;
    final bool canRight = offset < max - _edgeEpsilon;
    if (canLeft == _canScrollLeft && canRight == _canScrollRight) {
      return;
    }
    setState(() {
      _canScrollLeft = canLeft;
      _canScrollRight = canRight;
    });
  }

  Future<void> _pageBy(double delta) async {
    if (!_scrollController.hasClients) {
      return;
    }
    final double max = _scrollController.position.maxScrollExtent;
    final double next = (_scrollController.offset + delta).clamp(0, max);
    await _scrollController.animateTo(
      next,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
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
          boardWidth: widget.boardWidth,
          boardHeight: widget.boardHeight,
        ),
      ),
    );

    if (_lastColumnCount != packed.columns.length) {
      _lastColumnCount = packed.columns.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncEdgeVisibility());
    }

    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < packed.columns.length; i++) ...[
                if (i > 0) const SizedBox(width: KdsLayout.cardGap),
                SizedBox(
                  width: packed.columnWidth,
                  height: widget.boardHeight,
                  child: _OrderBoardColumn(segments: packed.columns[i]),
                ),
              ],
            ],
          ),
        ),
        if (_canScrollLeft)
          Align(
            alignment: Alignment.centerLeft,
            child: _BoardMoreControl(
              key: const Key('board-more-left'),
              isForward: false,
              onTap: () => _pageBy(-widget.boardWidth),
            ),
          ),
        if (_canScrollRight)
          Align(
            alignment: Alignment.centerRight,
            child: _BoardMoreControl(
              key: const Key('board-more-right'),
              isForward: true,
              onTap: () => _pageBy(widget.boardWidth),
            ),
          ),
      ],
    );
  }
}

class _BoardMoreControl extends StatelessWidget {
  const _BoardMoreControl({
    super.key,
    required this.isForward,
    required this.onTap,
  });

  final bool isForward;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.unit),
      child: Material(
        color: AppColors.chromeHeader.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadii.full),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.full),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gutter,
              vertical: AppSpacing.unit,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isForward) ...[
                  const Icon(
                    Icons.chevron_left,
                    color: AppColors.onStatusHeader,
                    size: 22,
                  ),
                  const SizedBox(width: 2),
                ],
                Text(
                  'More',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onStatusHeader,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (isForward) ...[
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.onStatusHeader,
                    size: 22,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderBoardColumn extends StatelessWidget {
  const _OrderBoardColumn({required this.segments});

  final List<CardSegment> segments;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (int i = 0; i < segments.length; i++) ...[
          if (i > 0) const SizedBox(height: KdsLayout.cardGap),
          OrderCard(segment: segments[i]),
        ],
      ],
    );
  }
}
