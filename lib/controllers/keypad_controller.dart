import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/kds_timing.dart';
import '../core/utils/keypad_buffer.dart';
import '../core/utils/keypad_key_map.dart';
import '../core/utils/keypad_targets.dart';
import '../core/utils/order_title_number.dart';
import '../models/item_quantity.dart';
import '../models/keypad_state.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../providers/providers.dart';
import '../views/kitchen_display/prep_line.dart';
import 'order_controller.dart';

/// Keyboard mode + type-ahead buffer. Mutations still go through
/// [OrderController]; this notifier only interprets [KeypadKey]s.
///
/// Providers live here (same as UrgencySettingsController) so this file can
/// import providers.dart without a circular re-export. Views import this
/// file directly — do not re-export [keypadProvider] from providers.dart.
class KeypadController extends Notifier<KeypadState> {
  @override
  KeypadState build() => KeypadState.initial;

  KeypadEffect handleKey(KeypadKey key, {required DateTime now}) {
    _expireFlash(now);
    final int? digit = keypadDigit(key);
    if (digit != null) {
      return _handleDigit(digit, now);
    }
    return switch (key) {
      KeypadKey.d0 ||
      KeypadKey.d1 ||
      KeypadKey.d2 ||
      KeypadKey.d3 ||
      KeypadKey.d4 ||
      KeypadKey.d5 ||
      KeypadKey.d6 ||
      KeypadKey.d7 ||
      KeypadKey.d8 ||
      KeypadKey.d9 => const KeypadEffectNone(),
      KeypadKey.enter => _handleEnter(now),
      KeypadKey.star => _handleStar(now),
      KeypadKey.plus => _handlePlusMinus(1, now),
      KeypadKey.minus => _handlePlusMinus(-1, now),
      KeypadKey.dot => _handleDot(),
      KeypadKey.slash => _handleSlash(now),
    };
  }

  void clearFocusIfMissing(Set<String> visibleOrderIds) {
    final String? id = state.focusedOrderId;
    if (id == null || visibleOrderIds.contains(id)) {
      return;
    }
    state = state.copyWith(
      clearFocusedOrderId: true,
      digits: '',
      clearDigitsAt: true,
    );
  }

  /// Idempotent. Used by the (later) panel-open helper for both tap and keys.
  void notePanelOpened(ItemGroupKey groupKey) {
    if (state.surface == KeypadSurface.breakdownPanel &&
        state.openGroupKey == groupKey) {
      return;
    }
    state = state.copyWith(
      surface: KeypadSurface.breakdownPanel,
      openGroupKey: groupKey,
      digits: '',
      clearDigitsAt: true,
      clearFlash: true,
      clearFlashUntil: true,
    );
  }

  /// Idempotent. Safe if the panel was already closed by `.`.
  void notePanelClosed() {
    if (state.surface != KeypadSurface.breakdownPanel) {
      return;
    }
    state = state.copyWith(
      surface: KeypadSurface.sidebar,
      clearOpenGroupKey: true,
      digits: '',
      clearDigitsAt: true,
    );
  }

  KeypadEffect _handleDigit(int digit, DateTime now) {
    final ({String digits, bool discardedStale}) next = applyKeypadDigit(
      digits: state.digits,
      digitsAt: state.digitsAt,
      digit: digit,
      now: now,
      timeout: KdsTiming.keypadBufferTimeout,
      maxLength: _digitCap,
    );
    if (next.digits == state.digits && !next.discardedStale) {
      return const KeypadEffectNone();
    }
    state = state.copyWith(
      digits: next.digits,
      digitsAt: now,
      clearFlash: true,
      clearFlashUntil: true,
    );
    return const KeypadEffectNone();
  }

  KeypadEffect _handleEnter(DateTime now) {
    return switch (state.surface) {
      KeypadSurface.board => _enterBoard(now),
      KeypadSurface.sidebar => _enterSidebar(now),
      KeypadSurface.breakdownPanel => _enterPanel(now),
    };
  }

  KeypadEffect _enterBoard(DateTime now) {
    final String? focusedId = state.focusedOrderId;
    if (focusedId == null) {
      if (state.digits.isEmpty) {
        return _pickEntryOrder();
      }
      return _confirmOrderNumber(now);
    }

    if (_isStale(focusedId)) {
      _setFlash('Use Clear (touch)', now);
      return const KeypadEffectNone();
    }

    final Order? order = ref.read(orderByIdProvider(focusedId));
    if (order == null) {
      _setFlash('No order', now, clearFocus: true);
      return const KeypadEffectNone();
    }

    if (state.digits.isEmpty) {
      return _enterOrderPrimary(order, now);
    }
    return _enterOrderItem(order, now);
  }

  /// Enter on a calm board: ring the next ticket that needs cooking, so the
  /// chef can reach a ticket (including one packed off-screen) without knowing
  /// its number.
  KeypadEffect _pickEntryOrder() {
    final String? id = entryBoardOrderId(
      ordered: ref.read(boardOrderedOrdersProvider),
      isStale: _isStale,
    );
    if (id == null) {
      return const KeypadEffectNone();
    }
    state = state.copyWith(
      focusedOrderId: id,
      digits: '',
      clearDigitsAt: true,
      clearFlash: true,
      clearFlashUntil: true,
    );
    return const KeypadEffectNone();
  }

  KeypadEffect _confirmOrderNumber(DateTime now) {
    final OrderTitleNumberSource source = ref.read(
      orderTitleNumberSourceProvider,
    );
    final List<Order> orders = ref.read(ordersForCurrentViewProvider);
    final String? id = orderIdForTypedNumber(
      orders: orders,
      typed: state.digits,
      titleNumber: (Order order) => orderTitleNumber(order, source),
    );
    if (id == null) {
      _setFlash('No order #${state.digits}', now);
      return const KeypadEffectNone();
    }
    state = state.copyWith(
      focusedOrderId: id,
      digits: '',
      clearDigitsAt: true,
      clearFlash: true,
      clearFlashUntil: true,
    );
    return const KeypadEffectNone();
  }

  KeypadEffect _enterOrderPrimary(Order order, DateTime now) {
    switch (order.status) {
      case OrderStatus.newOrder:
        unawaited(
          ref.read(orderControllerProvider.notifier).startOrder(order.id),
        );
      case OrderStatus.cooking:
        unawaited(
          ref.read(orderControllerProvider.notifier).completeOrder(order.id),
        );
      case OrderStatus.completed:
        _setFlash('Already completed', now);
      case OrderStatus.cancelled:
        _setFlash('Order cancelled', now);
    }
    return const KeypadEffectNone();
  }

  KeypadEffect _enterOrderItem(Order order, DateTime now) {
    if (order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled) {
      _setFlash('Order closed', now);
      return const KeypadEffectNone();
    }

    final int? index = elementIndexForTypedDigits(
      state.digits,
      order.items.length,
    );
    if (index == null) {
      _setFlash('No item ${state.digits}', now);
      return const KeypadEffectNone();
    }

    final OrderItem item = order.items[index];
    if (item.isRemoved) {
      _setFlash('Item removed', now);
      return const KeypadEffectNone();
    }

    final OrderController orders = ref.read(orderControllerProvider.notifier);
    if (order.status == OrderStatus.newOrder) {
      unawaited(
        orders.completeItems(<({String orderId, String itemId})>[
          (orderId: order.id, itemId: item.id),
        ]),
      );
    } else {
      unawaited(orders.toggleItemCompleted(order.id, item.id));
    }
    state = state.copyWith(
      digits: '',
      clearDigitsAt: true,
      clearFlash: true,
      clearFlashUntil: true,
    );
    return const KeypadEffectNone();
  }

  KeypadEffect _enterSidebar(DateTime now) {
    if (state.digits.isEmpty) {
      return const KeypadEffectNone();
    }
    final List<ItemQuantityEntry> entries = _sidebarEntries;
    final int? index = elementIndexForTypedDigits(state.digits, entries.length);
    if (index == null) {
      _setFlash('No item group ${state.digits}', now);
      return const KeypadEffectNone();
    }
    final ItemGroupKey groupKey = entries[index].key;
    state = state.copyWith(
      surface: KeypadSurface.breakdownPanel,
      openGroupKey: groupKey,
      digits: '',
      clearDigitsAt: true,
      clearFlash: true,
      clearFlashUntil: true,
    );
    return KeypadEffectOpenBreakdownPanel(groupKey);
  }

  KeypadEffect _enterPanel(DateTime now) {
    final ItemGroupKey? groupKey = state.openGroupKey;
    if (groupKey == null) {
      return const KeypadEffectNone();
    }
    final List<PrepLine> lines = ref.read(itemPrepBreakdownProvider(groupKey));
    if (state.digits.isEmpty) {
      final bool canCompleteAny = lines.any(
        (PrepLine line) => line.canComplete && !line.isCompleted,
      );
      if (!canCompleteAny) {
        _setFlash('Nothing to complete', now);
        return const KeypadEffectNone();
      }
      return const KeypadEffectCompleteAllPanelLines();
    }
    final int? index = elementIndexForTypedDigits(state.digits, lines.length);
    if (index == null) {
      _setFlash('No line ${state.digits}', now);
      return const KeypadEffectNone();
    }
    state = state.copyWith(
      digits: '',
      clearDigitsAt: true,
      clearFlash: true,
      clearFlashUntil: true,
    );
    return KeypadEffectCompletePanelLine(index);
  }

  KeypadEffect _handleStar(DateTime now) {
    final String? id = state.focusedOrderId;
    if (state.surface != KeypadSurface.board || id == null) {
      return const KeypadEffectNone();
    }
    if (_isStale(id)) {
      _setFlash('Use Clear (touch)', now);
      return const KeypadEffectNone();
    }
    final Order? order = ref.read(orderByIdProvider(id));
    if (order == null || order.status != OrderStatus.completed) {
      return const KeypadEffectNone();
    }
    unawaited(ref.read(orderControllerProvider.notifier).rollbackOrder(id));
    return const KeypadEffectNone();
  }

  /// Ringed ticket: hop to the next/previous ticket. Calm board: cycle tabs.
  ///
  /// The ring is the chef's cue for which of the two is live, and the tab flash
  /// makes an accidental tab change obvious (one press back undoes it).
  KeypadEffect _handlePlusMinus(int delta, DateTime now) {
    if (state.surface != KeypadSurface.board) {
      return KeypadEffectPageList(delta);
    }
    if (state.focusedOrderId != null) {
      return _stepFocusedOrder(delta, now);
    }
    final KdsTab current = ref.read(selectedKdsTabProvider);
    final KdsTab next = _cycleTab(current, delta);
    ref.read(selectedKdsTabProvider.notifier).state = next;
    _setFlash(_tabFlash(next), now, clearFocus: true);
    return const KeypadEffectNone();
  }

  /// Moves the ring one ticket along board reading order. The board's existing
  /// `focusedOrderId` listener does the scrolling, so an off-screen ticket
  /// comes into view without any extra plumbing here.
  KeypadEffect _stepFocusedOrder(int delta, DateTime now) {
    final List<Order> ordered = ref.read(boardOrderedOrdersProvider);
    final String? nextId = stepBoardOrderId(
      orderedIds: <String>[for (final Order order in ordered) order.id],
      currentId: state.focusedOrderId,
      delta: delta,
    );
    if (nextId == null) {
      _setFlash(delta > 0 ? 'End of board' : 'Start of board', now);
      return const KeypadEffectNone();
    }
    state = state.copyWith(
      focusedOrderId: nextId,
      digits: '',
      clearDigitsAt: true,
      clearFlash: true,
      clearFlashUntil: true,
    );
    return const KeypadEffectNone();
  }

  KeypadEffect _handleDot() {
    if (state.digits.isNotEmpty || state.flash != null) {
      state = state.copyWith(
        digits: '',
        clearDigitsAt: true,
        clearFlash: true,
        clearFlashUntil: true,
      );
      return const KeypadEffectNone();
    }
    if (state.surface == KeypadSurface.breakdownPanel) {
      state = state.copyWith(
        surface: KeypadSurface.sidebar,
        clearOpenGroupKey: true,
        digits: '',
        clearDigitsAt: true,
      );
      return const KeypadEffectCloseBreakdownPanel();
    }
    if (state.surface == KeypadSurface.sidebar) {
      state = state.copyWith(surface: KeypadSurface.board);
      return const KeypadEffectNone();
    }
    if (state.focusedOrderId != null) {
      state = state.copyWith(clearFocusedOrderId: true);
      return const KeypadEffectNone();
    }
    return const KeypadEffectNone();
  }

  KeypadEffect _handleSlash(DateTime now) {
    if (state.surface == KeypadSurface.breakdownPanel) {
      return const KeypadEffectNone();
    }
    if (!ref.read(productQuantityListVisibleProvider)) {
      _setFlash('Items list hidden', now);
      return const KeypadEffectNone();
    }
    final KeypadSurface next = state.surface == KeypadSurface.board
        ? KeypadSurface.sidebar
        : KeypadSurface.board;
    state = state.copyWith(
      surface: next,
      digits: '',
      clearDigitsAt: true,
      clearFlash: true,
      clearFlashUntil: true,
    );
    return const KeypadEffectNone();
  }

  void _expireFlash(DateTime now) {
    if (state.flash == null) {
      return;
    }
    if (isKeypadFlashExpired(flashUntil: state.flashUntil, now: now)) {
      state = state.copyWith(clearFlash: true, clearFlashUntil: true);
    }
  }

  void _setFlash(String message, DateTime now, {bool clearFocus = false}) {
    state = state.copyWith(
      clearFocusedOrderId: clearFocus,
      digits: '',
      clearDigitsAt: true,
      flash: message,
      flashUntil: now.add(KdsTiming.keypadFlashDuration),
    );
  }

  bool _isStale(String orderId) {
    return ref.read(staleLeftoverOrderIdsProvider).contains(orderId);
  }

  int get _digitCap {
    if (state.surface != KeypadSurface.board || state.focusedOrderId != null) {
      return 2;
    }
    return 4;
  }

  List<ItemQuantityEntry> get _sidebarEntries {
    return ref
        .read(itemQuantitiesProvider)
        .expand((ItemQuantitySection section) => section.entries)
        .toList();
  }
}

String _tabFlash(KdsTab tab) {
  return switch (tab) {
    KdsTab.cooking => 'Cooking tab',
    KdsTab.completed => 'Completed tab',
    KdsTab.cancelled => 'Cancelled tab',
  };
}

KdsTab _cycleTab(KdsTab current, int delta) {
  const List<KdsTab> tabs = <KdsTab>[
    KdsTab.cooking,
    KdsTab.completed,
    KdsTab.cancelled,
  ];
  final int index = tabs.indexOf(current);
  return tabs[(index + delta + tabs.length) % tabs.length];
}

final NotifierProvider<KeypadController, KeypadState> keypadProvider =
    NotifierProvider<KeypadController, KeypadState>(KeypadController.new);
