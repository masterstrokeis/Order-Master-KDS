import 'item_quantity.dart';

enum KeypadSurface { board, sidebar, breakdownPanel }

class KeypadState {
  const KeypadState({
    this.surface = KeypadSurface.board,
    this.focusedOrderId,
    this.openGroupKey,
    this.digits = '',
    this.digitsAt,
    this.flash,
    this.flashUntil,
    this.legendVisibleUntil,
  });

  static const KeypadState initial = KeypadState();

  final KeypadSurface surface;
  final String? focusedOrderId;

  /// Non-null only while the breakdown panel is open.
  final ItemGroupKey? openGroupKey;
  final String digits;
  final DateTime? digitsAt;
  final String? flash;
  final DateTime? flashUntil;
  final DateTime? legendVisibleUntil;

  KeypadState copyWith({
    KeypadSurface? surface,
    String? focusedOrderId,
    bool clearFocusedOrderId = false,
    ItemGroupKey? openGroupKey,
    bool clearOpenGroupKey = false,
    String? digits,
    DateTime? digitsAt,
    bool clearDigitsAt = false,
    String? flash,
    bool clearFlash = false,
    DateTime? flashUntil,
    bool clearFlashUntil = false,
    DateTime? legendVisibleUntil,
    bool clearLegendVisibleUntil = false,
  }) {
    return KeypadState(
      surface: surface ?? this.surface,
      focusedOrderId: clearFocusedOrderId
          ? null
          : (focusedOrderId ?? this.focusedOrderId),
      openGroupKey: clearOpenGroupKey
          ? null
          : (openGroupKey ?? this.openGroupKey),
      digits: digits ?? this.digits,
      digitsAt: clearDigitsAt ? null : (digitsAt ?? this.digitsAt),
      flash: clearFlash ? null : (flash ?? this.flash),
      flashUntil: clearFlashUntil ? null : (flashUntil ?? this.flashUntil),
      legendVisibleUntil: clearLegendVisibleUntil
          ? null
          : (legendVisibleUntil ?? this.legendVisibleUntil),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is KeypadState &&
        other.surface == surface &&
        other.focusedOrderId == focusedOrderId &&
        other.openGroupKey == openGroupKey &&
        other.digits == digits &&
        other.digitsAt == digitsAt &&
        other.flash == flash &&
        other.flashUntil == flashUntil &&
        other.legendVisibleUntil == legendVisibleUntil;
  }

  @override
  int get hashCode => Object.hash(
    surface,
    focusedOrderId,
    openGroupKey,
    digits,
    digitsAt,
    flash,
    flashUntil,
    legendVisibleUntil,
  );
}

sealed class KeypadEffect {
  const KeypadEffect();
}

final class KeypadEffectNone extends KeypadEffect {
  const KeypadEffectNone();

  @override
  bool operator ==(Object other) => other is KeypadEffectNone;

  @override
  int get hashCode => 0;
}

final class KeypadEffectOpenBreakdownPanel extends KeypadEffect {
  const KeypadEffectOpenBreakdownPanel(this.groupKey);

  final ItemGroupKey groupKey;

  @override
  bool operator ==(Object other) {
    return other is KeypadEffectOpenBreakdownPanel &&
        other.groupKey == groupKey;
  }

  @override
  int get hashCode => groupKey.hashCode;
}

final class KeypadEffectCloseBreakdownPanel extends KeypadEffect {
  const KeypadEffectCloseBreakdownPanel();

  @override
  bool operator ==(Object other) => other is KeypadEffectCloseBreakdownPanel;

  @override
  int get hashCode => 1;
}

final class KeypadEffectCompleteAllPanelLines extends KeypadEffect {
  const KeypadEffectCompleteAllPanelLines();

  @override
  bool operator ==(Object other) => other is KeypadEffectCompleteAllPanelLines;

  @override
  int get hashCode => 2;
}

final class KeypadEffectCompletePanelLine extends KeypadEffect {
  const KeypadEffectCompletePanelLine(this.index);

  final int index;

  @override
  bool operator ==(Object other) {
    return other is KeypadEffectCompletePanelLine && other.index == index;
  }

  @override
  int get hashCode => index.hashCode;
}

/// [delta] is +1 for `+` (forward) and -1 for `-` (back).
final class KeypadEffectPageList extends KeypadEffect {
  const KeypadEffectPageList(this.delta);

  final int delta;

  @override
  bool operator ==(Object other) {
    return other is KeypadEffectPageList && other.delta == delta;
  }

  @override
  int get hashCode => delta.hashCode;
}
