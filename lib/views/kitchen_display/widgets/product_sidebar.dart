import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/kds_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/providers.dart';
import 'product_prep_breakdown_panel.dart';
import 'product_quantity_row.dart';

class ProductSidebar extends ConsumerWidget {
  const ProductSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<ProductQuantitySection> sections = ref.watch(
      productQuantitiesProvider,
    );

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
                    'PRODUCT',
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
              itemCount: sections.length,
              itemBuilder: (BuildContext context, int index) {
                return _ProductCategorySection(section: sections[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCategorySection extends StatelessWidget {
  const _ProductCategorySection({required this.section});

  final ProductQuantitySection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gutter,
              vertical: AppSpacing.unit,
            ),
            child: Text(
              section.category.name,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.chromeOnSurfaceDim,
                fontSize: 11,
                letterSpacing: 1.4,
              ),
            ),
          ),
          for (final ProductQuantityEntry entry in section.entries)
            ProductQuantityRow(
              name: entry.product.name,
              quantity: entry.quantity,
              onTap: () {
                unawaited(
                  showProductPrepBreakdownPanel(
                    context: context,
                    productId: entry.product.id,
                    productName: entry.product.name,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
