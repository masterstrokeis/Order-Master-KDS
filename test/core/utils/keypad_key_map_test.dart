import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/utils/keypad_key_map.dart';

void main() {
  group('keypadKeyForPhysical maps every operational numpad key', () {
    const List<(PhysicalKeyboardKey, KeypadKey)> numpad =
        <(PhysicalKeyboardKey, KeypadKey)>[
          (PhysicalKeyboardKey.numpad0, KeypadKey.d0),
          (PhysicalKeyboardKey.numpad1, KeypadKey.d1),
          (PhysicalKeyboardKey.numpad2, KeypadKey.d2),
          (PhysicalKeyboardKey.numpad3, KeypadKey.d3),
          (PhysicalKeyboardKey.numpad4, KeypadKey.d4),
          (PhysicalKeyboardKey.numpad5, KeypadKey.d5),
          (PhysicalKeyboardKey.numpad6, KeypadKey.d6),
          (PhysicalKeyboardKey.numpad7, KeypadKey.d7),
          (PhysicalKeyboardKey.numpad8, KeypadKey.d8),
          (PhysicalKeyboardKey.numpad9, KeypadKey.d9),
          (PhysicalKeyboardKey.numpadEnter, KeypadKey.enter),
          (PhysicalKeyboardKey.numpadAdd, KeypadKey.plus),
          (PhysicalKeyboardKey.numpadSubtract, KeypadKey.minus),
          (PhysicalKeyboardKey.numpadMultiply, KeypadKey.star),
          (PhysicalKeyboardKey.numpadDecimal, KeypadKey.dot),
          (PhysicalKeyboardKey.numpadDivide, KeypadKey.slash),
        ];

    for (final (PhysicalKeyboardKey physical, KeypadKey expected) in numpad) {
      test('$physical → $expected', () {
        expect(keypadKeyForPhysical(physical), expected);
      });
    }

    test('all operational numpad keys are mapped (0-9, Enter, + - * . /)', () {
      expect(numpad, hasLength(16));
    });
  });

  group('secondary main-row mappings do not shadow numpad keys', () {
    const List<(PhysicalKeyboardKey, PhysicalKeyboardKey, KeypadKey)>
    pairs = <(PhysicalKeyboardKey, PhysicalKeyboardKey, KeypadKey)>[
      (PhysicalKeyboardKey.digit0, PhysicalKeyboardKey.numpad0, KeypadKey.d0),
      (PhysicalKeyboardKey.digit1, PhysicalKeyboardKey.numpad1, KeypadKey.d1),
      (PhysicalKeyboardKey.digit2, PhysicalKeyboardKey.numpad2, KeypadKey.d2),
      (PhysicalKeyboardKey.digit3, PhysicalKeyboardKey.numpad3, KeypadKey.d3),
      (PhysicalKeyboardKey.digit4, PhysicalKeyboardKey.numpad4, KeypadKey.d4),
      (PhysicalKeyboardKey.digit5, PhysicalKeyboardKey.numpad5, KeypadKey.d5),
      (PhysicalKeyboardKey.digit6, PhysicalKeyboardKey.numpad6, KeypadKey.d6),
      (PhysicalKeyboardKey.digit7, PhysicalKeyboardKey.numpad7, KeypadKey.d7),
      (PhysicalKeyboardKey.digit8, PhysicalKeyboardKey.numpad8, KeypadKey.d8),
      (PhysicalKeyboardKey.digit9, PhysicalKeyboardKey.numpad9, KeypadKey.d9),
      (
        PhysicalKeyboardKey.enter,
        PhysicalKeyboardKey.numpadEnter,
        KeypadKey.enter,
      ),
      (
        PhysicalKeyboardKey.period,
        PhysicalKeyboardKey.numpadDecimal,
        KeypadKey.dot,
      ),
      (
        PhysicalKeyboardKey.slash,
        PhysicalKeyboardKey.numpadDivide,
        KeypadKey.slash,
      ),
      (
        PhysicalKeyboardKey.minus,
        PhysicalKeyboardKey.numpadSubtract,
        KeypadKey.minus,
      ),
    ];

    for (final (
          PhysicalKeyboardKey main,
          PhysicalKeyboardKey numpad,
          KeypadKey expected,
        )
        in pairs) {
      test('$main and $numpad both → $expected', () {
        expect(keypadKeyForPhysical(main), expected);
        expect(keypadKeyForPhysical(numpad), expected);
        expect(main, isNot(numpad));
      });
    }

    test('main-row equal is not mapped (no colliding +)', () {
      expect(keypadKeyForPhysical(PhysicalKeyboardKey.equal), isNull);
    });
  });

  test('unmapped physical keys return null', () {
    const List<PhysicalKeyboardKey> unmapped = <PhysicalKeyboardKey>[
      PhysicalKeyboardKey.keyA,
      PhysicalKeyboardKey.keyZ,
      PhysicalKeyboardKey.f1,
      PhysicalKeyboardKey.shiftLeft,
      PhysicalKeyboardKey.controlLeft,
      PhysicalKeyboardKey.altLeft,
      PhysicalKeyboardKey.arrowUp,
      PhysicalKeyboardKey.arrowDown,
      PhysicalKeyboardKey.arrowLeft,
      PhysicalKeyboardKey.arrowRight,
      PhysicalKeyboardKey.pageDown,
      PhysicalKeyboardKey.pageUp,
      PhysicalKeyboardKey.end,
      PhysicalKeyboardKey.home,
      PhysicalKeyboardKey.delete,
      PhysicalKeyboardKey.insert,
      PhysicalKeyboardKey.numLock,
      PhysicalKeyboardKey.space,
      PhysicalKeyboardKey.backspace,
      PhysicalKeyboardKey.comma,
    ];
    for (final PhysicalKeyboardKey key in unmapped) {
      expect(keypadKeyForPhysical(key), isNull, reason: '$key');
    }
  });

  test('mapping takes PhysicalKeyboardKey only — no logical-key parameter', () {
    // keypadKeyForPhysical(PhysicalKeyboardKey) is the entire API. The same
    // physical numpad8 maps regardless of what logical key Windows would
    // report under NumLock on vs off.
    expect(keypadKeyForPhysical(PhysicalKeyboardKey.numpad8), KeypadKey.d8);
  });

  group('keypadDigit', () {
    test('maps d0–d9 to 0–9', () {
      expect(keypadDigit(KeypadKey.d0), 0);
      expect(keypadDigit(KeypadKey.d1), 1);
      expect(keypadDigit(KeypadKey.d2), 2);
      expect(keypadDigit(KeypadKey.d3), 3);
      expect(keypadDigit(KeypadKey.d4), 4);
      expect(keypadDigit(KeypadKey.d5), 5);
      expect(keypadDigit(KeypadKey.d6), 6);
      expect(keypadDigit(KeypadKey.d7), 7);
      expect(keypadDigit(KeypadKey.d8), 8);
      expect(keypadDigit(KeypadKey.d9), 9);
    });

    test('non-digit keys return null', () {
      expect(keypadDigit(KeypadKey.enter), isNull);
      expect(keypadDigit(KeypadKey.plus), isNull);
      expect(keypadDigit(KeypadKey.minus), isNull);
      expect(keypadDigit(KeypadKey.star), isNull);
      expect(keypadDigit(KeypadKey.dot), isNull);
      expect(keypadDigit(KeypadKey.slash), isNull);
    });
  });
}
