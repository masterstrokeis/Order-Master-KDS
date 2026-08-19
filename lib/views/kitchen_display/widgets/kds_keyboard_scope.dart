import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/keypad_controller.dart';
import '../../../core/utils/keypad_key_map.dart';
import '../../../models/item_quantity.dart';
import '../../../models/keypad_state.dart';
import '../../../models/order_model.dart';
import '../../../providers/providers.dart';
import 'product_prep_breakdown_panel.dart';

/// Lets [ProductSidebar] register the list it owns so board-scope `+/-`
/// can page it. The breakdown panel is a separate route and passes its
/// own [ScrollController] into [handleKeypadEvent] instead.
class KeypadSidebarScroller extends InheritedWidget {
  const KeypadSidebarScroller({
    super.key,
    required this.attach,
    required super.child,
  });

  final void Function(ScrollController? controller) attach;

  static KeypadSidebarScroller? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<KeypadSidebarScroller>();
  }

  @override
  bool updateShouldNotify(KeypadSidebarScroller oldWidget) => false;
}

/// Shared by the board [Focus] and the breakdown-panel [Focus].
///
/// [DateTime.now] is called here and nowhere else in the keypad path.
KeyEventResult handleKeypadEvent(
  KeyEvent event,
  WidgetRef ref,
  BuildContext context, {
  ScrollController? listController,
  Future<void> Function()? onCompleteAllPanelLines,
  Future<void> Function(int index)? onCompletePanelLine,
}) {
  if (event is! KeyDownEvent) {
    return KeyEventResult.ignored;
  }
  final KeypadKey? key = keypadKeyForPhysical(event.physicalKey);
  if (key == null) {
    return KeyEventResult.ignored;
  }
  final KeypadEffect effect = ref
      .read(keypadProvider.notifier)
      .handleKey(key, now: DateTime.now());
  unawaited(
    _performKeypadEffect(
      effect,
      ref,
      context,
      listController: listController,
      onCompleteAllPanelLines: onCompleteAllPanelLines,
      onCompletePanelLine: onCompletePanelLine,
    ),
  );
  return KeyEventResult.handled;
}

Future<void> _performKeypadEffect(
  KeypadEffect effect,
  WidgetRef ref,
  BuildContext context, {
  ScrollController? listController,
  Future<void> Function()? onCompleteAllPanelLines,
  Future<void> Function(int index)? onCompletePanelLine,
}) async {
  switch (effect) {
    case KeypadEffectNone():
      return;
    case KeypadEffectOpenBreakdownPanel(:final ItemGroupKey groupKey):
      await openPrepBreakdownPanel(context, ref, groupKey);
    case KeypadEffectCloseBreakdownPanel():
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    case KeypadEffectCompleteAllPanelLines():
      await onCompleteAllPanelLines?.call();
    case KeypadEffectCompletePanelLine(:final int index):
      await onCompletePanelLine?.call(index);
    case KeypadEffectPageList(:final int delta):
      await _pageKeypadList(listController, delta);
  }
}

Future<void> _pageKeypadList(ScrollController? controller, int delta) async {
  if (controller == null || !controller.hasClients) {
    return;
  }
  final double view = controller.position.viewportDimension;
  final double max = controller.position.maxScrollExtent;
  final double next = (controller.offset + delta * view).clamp(0.0, max);
  await controller.animateTo(
    next,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOutCubic,
  );
}

/// Brackets the breakdown-panel route so keypad surface stays in sync after
/// a barrier-dismiss or close-button tap as well as a `.` close.
///
/// Used by both the sidebar tap and the keyboard open-panel effect.
Future<void> openPrepBreakdownPanel(
  BuildContext context,
  WidgetRef ref,
  ItemGroupKey groupKey,
) async {
  ref.read(keypadProvider.notifier).notePanelOpened(groupKey);
  await showProductPrepBreakdownPanel(
    context: context,
    groupKey: groupKey,
    displayTitle: groupKey.displayTitle,
  );
  if (!context.mounted) {
    return;
  }
  ref.read(keypadProvider.notifier).notePanelClosed();
  Focus.maybeOf(context)?.requestFocus();
}

/// Keeps the kitchen display's [Focus] for the whole shift.
///
/// Nothing on this screen needs keyboard focus. Excluding the whole subtree
/// keeps this node focused for the entire shift and structurally guarantees
/// no control — the station dropdown above all — can receive a numpad key.
/// This is the regression guard; there is deliberately no per-control key
/// ignore list to drift out of date.
class KdsKeyboardScope extends ConsumerStatefulWidget {
  const KdsKeyboardScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KdsKeyboardScope> createState() => _KdsKeyboardScopeState();
}

class _KdsKeyboardScopeState extends ConsumerState<KdsKeyboardScope> {
  final FocusNode _node = FocusNode(debugLabel: 'kds-keyboard-scope');
  ScrollController? _sidebarListController;
  KeypadController? _cachedKeypadController;

  void _attachSidebarScroller(ScrollController? controller) {
    _sidebarListController = controller;
  }

  @override
  void dispose() {
    // Prevent Flutter test "pending timers" assertions by cancelling the
    // keypad legend timer before the widget tree is torn down.
    // (Cache [KeypadController] in build; never use [ref] directly in dispose.)
    _cachedKeypadController?.clearLegendVisibleUntil();
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _cachedKeypadController ??= ref.read(keypadProvider.notifier);

    ref.listen<List<Order>>(ordersForCurrentViewProvider, (
      List<Order>? previous,
      List<Order> next,
    ) {
      ref
          .read(keypadProvider.notifier)
          .clearFocusIfMissing(next.map((Order order) => order.id).toSet());
    });

    return KeypadSidebarScroller(
      attach: _attachSidebarScroller,
      child: Focus(
        key: const Key('kds-keyboard-scope'),
        focusNode: _node,
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent event) => handleKeypadEvent(
          event,
          ref,
          context,
          listController: _sidebarListController,
        ),
        child: ExcludeFocus(child: widget.child),
      ),
    );
  }
}
