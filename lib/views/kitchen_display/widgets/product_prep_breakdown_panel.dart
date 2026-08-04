import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/kds_layout.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/providers.dart';
import '../prep_line.dart';
import 'prep_line_row.dart';

Future<void> showProductPrepBreakdownPanel({
  required BuildContext context,
  required String productId,
  required String productName,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close $productName preparation breakdown',
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
                child: ProductPrepBreakdownPanel(
                  productId: productId,
                  productName: productName,
                ),
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

class ProductPrepBreakdownPanel extends ConsumerWidget {
  const ProductPrepBreakdownPanel({
    super.key,
    required this.productId,
    required this.productName,
  });

  final String productId;
  final String productName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<PrepLine> lines = ref.watch(
      productPrepBreakdownProvider(productId),
    );
    final int pendingQuantity = lines.fold(
      0,
      (int total, PrepLine line) => total + line.quantity,
    );
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Semantics(
      namesRoute: true,
      label: '$productName preparation breakdown',
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
                          productName,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.unit / 2),
                        Text(
                          '$pendingQuantity pending',
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
              child: lines.isEmpty
                  ? const _NothingPending()
                  : ListView.separated(
                      key: const ValueKey<String>('prep-breakdown-list'),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.unit,
                      ),
                      itemCount: lines.length,
                      separatorBuilder: (BuildContext context, int index) {
                        return Divider(
                          height: 1,
                          indent: AppSpacing.gutter,
                          endIndent: AppSpacing.gutter,
                          color: colors.outlineVariant,
                        );
                      },
                      itemBuilder: (BuildContext context, int index) {
                        return PrepLineRow(
                          key: ValueKey<String>(
                            '${lines[index].orderId}:$index',
                          ),
                          line: lines[index],
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

class _NothingPending extends StatelessWidget {
  const _NothingPending();

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
              'Nothing pending',
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
