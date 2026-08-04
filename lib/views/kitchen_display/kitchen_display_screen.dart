import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/order_controller.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/order_model.dart';
import 'widgets/kds_top_bar.dart';
import 'widgets/order_board.dart';
import 'widgets/product_sidebar.dart';

class KitchenDisplayScreen extends ConsumerWidget {
  const KitchenDisplayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Order>> ordersAsync = ref.watch(
      orderControllerProvider,
    );

    return Scaffold(
      body: Column(
        children: [
          const KdsTopBar(),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stackTrace) => Center(
                child: Text('Failed to load orders: $error'),
              ),
              data: (_) => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ProductSidebar(),
                  Expanded(
                    child: ColoredBox(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.pageMargin),
                        child: LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                return OrderBoard(
                                  boardWidth: constraints.maxWidth,
                                  boardHeight: constraints.maxHeight,
                                );
                              },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
