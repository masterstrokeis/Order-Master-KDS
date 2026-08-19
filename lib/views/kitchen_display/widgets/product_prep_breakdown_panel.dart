import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/keypad_controller.dart';
import '../../../core/constants/kds_layout.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/complete_items_result.dart';
import '../../../models/item_quantity.dart';
import '../../../models/keypad_state.dart';
import '../../../providers/providers.dart';
import '../prep_line.dart';
import 'kds_keyboard_scope.dart';
import 'keypad_type_ahead_indicator.dart';
import 'prep_line_row.dart';

Future<void> showProductPrepBreakdownPanel({
  required BuildContext context,
  required ItemGroupKey groupKey,
  required String displayTitle,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close $displayTitle preparation breakdown',
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
                  groupKey: groupKey,
                  displayTitle: displayTitle,
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

class ProductPrepBreakdownPanel extends ConsumerStatefulWidget {
  const ProductPrepBreakdownPanel({
    super.key,
    required this.groupKey,
    required this.displayTitle,
  });

  final ItemGroupKey groupKey;
  final String displayTitle;

  @override
  ConsumerState<ProductPrepBreakdownPanel> createState() =>
      _ProductPrepBreakdownPanelState();
}

class _ProductPrepBreakdownPanelState
    extends ConsumerState<ProductPrepBreakdownPanel> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'panel-keyboard-scope');
  final ScrollController _scrollController = ScrollController();
  String? _batchResultMessage;
  bool _isCompletingAll = false;

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _completeAll(List<PrepLine> lines) async {
    if (_isCompletingAll) {
      return;
    }

    final List<({String orderId, String itemId})> targets = lines
        .where((PrepLine line) => line.canComplete && !line.isCompleted)
        .map((PrepLine line) => (orderId: line.orderId, itemId: line.itemId))
        .toList();

    if (targets.isEmpty) {
      return;
    }

    setState(() {
      _isCompletingAll = true;
      _batchResultMessage = null;
    });

    final CompleteItemsResult result = await ref
        .read(orderControllerProvider.notifier)
        .completeItems(targets);

    if (!mounted) {
      return;
    }

    setState(() {
      _isCompletingAll = false;
      _batchResultMessage = _formatBatchResult(result, targets.length);
    });
  }

  String _formatBatchResult(CompleteItemsResult result, int requested) {
    final StringBuffer buffer = StringBuffer(
      'Completed ${result.completed} of $requested.',
    );
    if (result.skippedNotStarted > 0) {
      buffer.write(
        ' ${result.skippedNotStarted} skipped (ticket not started).',
      );
    }
    if (result.failedDisplayNumbers.isNotEmpty) {
      final String failedOrders = result.failedDisplayNumbers.join(', ');
      buffer.write(' ${result.failed} failed: Order #$failedOrders.');
    }
    return buffer.toString();
  }

  Future<void> _completeLine(PrepLine line) async {
    if (!line.canComplete || line.isCompleted) {
      return;
    }
    final CompleteItemsResult result = await ref
        .read(orderControllerProvider.notifier)
        .completeItems(<({String orderId, String itemId})>[
          (orderId: line.orderId, itemId: line.itemId),
        ]);
    if (!mounted) {
      return;
    }
    if (result.skippedNotStarted > 0 || result.failed > 0) {
      setState(() {
        _batchResultMessage = _formatBatchResult(result, 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<PrepLine> lines = ref.watch(
      itemPrepBreakdownProvider(widget.groupKey),
    );
    final int pendingQuantity = lines.fold(
      0,
      (int total, PrepLine line) => total + line.quantity,
    );
    final bool canCompleteAny = lines.any(
      (PrepLine line) => line.canComplete && !line.isCompleted,
    );
    final bool showLineBadges = ref.watch(
      keypadProvider.select(
        (KeypadState state) => state.surface == KeypadSurface.breakdownPanel,
      ),
    );
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Semantics(
      namesRoute: true,
      label: '${widget.displayTitle} preparation breakdown',
      child: Focus(
        key: const Key('panel-keyboard-scope'),
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent event) => handleKeypadEvent(
          event,
          ref,
          context,
          listController: _scrollController,
          onCompleteAllPanelLines: () => _completeAll(
            ref.read(itemPrepBreakdownProvider(widget.groupKey)),
          ),
          onCompletePanelLine: (int index) async {
            final List<PrepLine> current = ref.read(
              itemPrepBreakdownProvider(widget.groupKey),
            );
            if (index < 0 || index >= current.length) {
              return;
            }
            await _completeLine(current[index]);
          },
        ),
        child: ExcludeFocus(
          child: Stack(
            children: [
              Material(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.unit,
                                  ),
                                  child: Text(
                                    widget.displayTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$pendingQuantity remaining',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ),
                              if (canCompleteAny)
                                TextButton(
                                  key: const ValueKey<String>(
                                    'complete-all-button',
                                  ),
                                  onPressed: _isCompletingAll
                                      ? null
                                      : () => _completeAll(lines),
                                  child: _isCompletingAll
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Complete all'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_batchResultMessage != null)
                      MaterialBanner(
                        content: Text(_batchResultMessage!),
                        leading: const Icon(Icons.info_outline),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () =>
                                setState(() => _batchResultMessage = null),
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    Divider(height: 1, color: colors.outline),
                    Expanded(
                      child: lines.isEmpty
                          ? const _NothingPending()
                          : ListView.separated(
                              key: const ValueKey<String>(
                                'prep-breakdown-list',
                              ),
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.unit,
                              ),
                              itemCount: lines.length,
                              separatorBuilder:
                                  (BuildContext context, int index) {
                                    return Divider(
                                      height: 1,
                                      indent: AppSpacing.gutter,
                                      endIndent: AppSpacing.gutter,
                                      color: colors.outlineVariant,
                                    );
                                  },
                              itemBuilder: (BuildContext context, int index) {
                                final PrepLine line = lines[index];
                                return PrepLineRow(
                                  key: ValueKey<String>(
                                    '${line.orderId}:${line.itemId}',
                                  ),
                                  line: line,
                                  numberBadge: showLineBadges
                                      ? index + 1
                                      : null,
                                  onComplete:
                                      line.canComplete && !line.isCompleted
                                      ? () => _completeLine(line)
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              const KeypadTypeAheadIndicator(),
            ],
          ),
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
