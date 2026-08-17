import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/kds_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/item_quantity.dart';
import '../../../providers/providers.dart';
import 'product_prep_breakdown_panel.dart';
import 'product_quantity_row.dart';

class ProductSidebar extends ConsumerWidget {
  const ProductSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<ItemQuantityEntry> entries = ref
        .watch(itemQuantitiesProvider)
        .expand((ItemQuantitySection section) => section.entries)
        .toList();

    return Container(
      width: KdsLayout.sidebarWidth,
      color: AppColors.chromeSidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'ITEMS',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.chromeOnSurfaceMuted,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Text(
                  'QTY',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.chromeOnSurfaceMuted,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.chromeBorder),
          Expanded(
            child: ListView.builder(
              // Sidebar may scroll independently; board itself never scrolls.
              padding: const EdgeInsets.only(bottom: AppSpacing.pageMargin),
              itemCount: entries.length,
              itemBuilder: (BuildContext context, int index) {
                final ItemQuantityEntry entry = entries[index];
                return ProductQuantityRow(
                  name: entry.key.name,
                  modifierText: entry.key.modifierText.isEmpty
                      ? null
                      : entry.key.modifierText,
                  quantity: entry.quantity,
                  onTap: () {
                    unawaited(
                      showProductPrepBreakdownPanel(
                        context: context,
                        groupKey: entry.key,
                        displayTitle: entry.key.displayTitle,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
