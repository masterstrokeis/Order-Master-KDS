import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/keypad_controller.dart';
import '../../../core/constants/kds_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/item_quantity.dart';
import '../../../models/keypad_state.dart';
import '../../../providers/providers.dart';
import 'kds_keyboard_scope.dart';
import 'product_quantity_row.dart';

class ProductSidebar extends ConsumerStatefulWidget {
  const ProductSidebar({super.key});

  @override
  ConsumerState<ProductSidebar> createState() => _ProductSidebarState();
}

class _ProductSidebarState extends ConsumerState<ProductSidebar> {
  final ScrollController _scrollController = ScrollController();
  void Function(ScrollController?)? _attachScroller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachScroller = KeypadSidebarScroller.maybeOf(context)?.attach;
    _attachScroller?.call(_scrollController);
  }

  @override
  void dispose() {
    _attachScroller?.call(null);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<ItemQuantityEntry> entries = ref
        .watch(itemQuantitiesProvider)
        .expand((ItemQuantitySection section) => section.entries)
        .toList();
    final bool keyboardActive = ref.watch(
      keypadProvider.select(
        (KeypadState state) => state.surface == KeypadSurface.sidebar,
      ),
    );

    final Widget body = Container(
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
              controller: _scrollController,
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
                  // Sidebar badges render only while keyboard-active — no
                  // packing depends on this list, so they are not reserved.
                  numberBadge: keyboardActive ? index + 1 : null,
                  onTap: () {
                    unawaited(openPrepBreakdownPanel(context, ref, entry.key));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );

    if (!keyboardActive) {
      return body;
    }

    return DecoratedBox(
      key: const Key('sidebar-keyboard-focus'),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.keyboardFocus,
          width: KdsLayout.cardKeyboardFocusBorderWidth,
        ),
      ),
      child: body,
    );
  }
}
