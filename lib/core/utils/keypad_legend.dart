import '../../models/order_model.dart';

/// Which keyboard surface the cheat-sheet is describing.
///
/// Kept here (not on [KeypadState]) so this helper compiles without the
/// controller/model from a later step. The controller maps its surface onto
/// this enum when the legend bar is wired.
enum KeypadLegendSurface { board, sidebar, breakdownPanel }

class KeypadLegendEntry {
  const KeypadLegendEntry({required this.keyLabel, required this.action});

  final String keyLabel;
  final String action;
}

class KeypadLegendContext {
  const KeypadLegendContext({
    required this.surface,
    this.focusedStatus,
    this.hasDigits = false,
  });

  final KeypadLegendSurface surface;

  /// Non-null when an order is focused on the board.
  final OrderStatus? focusedStatus;
  final bool hasDigits;
}

/// Contextual cheat-sheet rows for the always-visible legend bar.
///
/// `+/-` reads Next ticket while a ticket is ringed, Tab on a calm board,
/// Scroll items in the sidebar, Scroll lines in the panel. Enter reads Pick
/// ticket / Start / Complete / Toggle item / Complete all according to
/// surface, focused status, and whether digits are buffered.
List<KeypadLegendEntry> keypadLegendFor(KeypadLegendContext context) {
  return <KeypadLegendEntry>[
    KeypadLegendEntry(keyLabel: '0-9', action: _digitsAction(context)),
    KeypadLegendEntry(keyLabel: 'Enter', action: _enterAction(context)),
    KeypadLegendEntry(keyLabel: '+/-', action: _plusMinusAction(context)),
    KeypadLegendEntry(keyLabel: '*', action: _starAction(context)),
    KeypadLegendEntry(keyLabel: '.', action: _dotAction(context)),
    KeypadLegendEntry(keyLabel: '/', action: _slashAction(context)),
  ];
}

String _digitsAction(KeypadLegendContext context) {
  return switch (context.surface) {
    KeypadLegendSurface.board =>
      context.focusedStatus == null ? 'Order #' : 'Item #',
    KeypadLegendSurface.sidebar => 'Item group',
    KeypadLegendSurface.breakdownPanel => 'Line #',
  };
}

String _enterAction(KeypadLegendContext context) {
  return switch (context.surface) {
    KeypadLegendSurface.board => _boardEnterAction(context),
    KeypadLegendSurface.sidebar => context.hasDigits ? 'Open' : '—',
    KeypadLegendSurface.breakdownPanel =>
      context.hasDigits ? 'Complete line' : 'Complete all',
  };
}

String _boardEnterAction(KeypadLegendContext context) {
  final OrderStatus? status = context.focusedStatus;
  if (status == null) {
    return context.hasDigits ? 'Confirm' : 'Pick ticket';
  }
  if (context.hasDigits) {
    return switch (status) {
      OrderStatus.newOrder || OrderStatus.cooking => 'Toggle item',
      OrderStatus.completed || OrderStatus.cancelled => '—',
    };
  }
  return switch (status) {
    OrderStatus.newOrder => 'Start',
    OrderStatus.cooking => 'Complete',
    OrderStatus.completed || OrderStatus.cancelled => '—',
  };
}

String _plusMinusAction(KeypadLegendContext context) {
  return switch (context.surface) {
    KeypadLegendSurface.board =>
      context.focusedStatus == null ? 'Tab' : 'Next ticket',
    KeypadLegendSurface.sidebar => 'Scroll items',
    KeypadLegendSurface.breakdownPanel => 'Scroll lines',
  };
}

String _starAction(KeypadLegendContext context) {
  if (context.surface == KeypadLegendSurface.board &&
      context.focusedStatus == OrderStatus.completed) {
    return 'Rollback';
  }
  return '—';
}

String _dotAction(KeypadLegendContext context) {
  return context.surface == KeypadLegendSurface.breakdownPanel
      ? 'Close'
      : 'Clear';
}

String _slashAction(KeypadLegendContext context) {
  return switch (context.surface) {
    KeypadLegendSurface.board => 'Items',
    KeypadLegendSurface.sidebar => 'Board',
    KeypadLegendSurface.breakdownPanel => '—',
  };
}
