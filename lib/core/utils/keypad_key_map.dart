import 'package:flutter/services.dart';

// Numpad dispatch reads PhysicalKeyboardKey ONLY.
//
// With NumLock off, Windows reports numpad keys as navigation logical keys
// (arrowUp, pageDown, end, delete...); with NumLock on it reports digits.
// physicalKey comes from the HID usage code and is identical either way, so
// physical dispatch is the only way this board keeps working after a knocked
// keypad or a driver reset. Never read event.logicalKey here, and never route
// these keys through Shortcuts / SingleActivator / CallbackShortcuts / Actions
// — those match on logical keys and would break silently.

/// The numpad vocabulary this board understands (0-9, Enter, + - * . /).
enum KeypadKey {
  d0,
  d1,
  d2,
  d3,
  d4,
  d5,
  d6,
  d7,
  d8,
  d9,
  enter,
  plus,
  minus,
  star,
  dot,
  slash,
}

/// Maps a physical key to [KeypadKey].
///
/// Primary: numpad 0–9, Enter, +, -, *, ., /. Secondary (dev/laptop, cannot
/// the numpad set): main-row digits, Enter, period, slash, minus.
/// Unmapped keys — including every navigation physical key — return null.
KeypadKey? keypadKeyForPhysical(PhysicalKeyboardKey key) {
  return switch (key) {
    PhysicalKeyboardKey.numpad0 || PhysicalKeyboardKey.digit0 => KeypadKey.d0,
    PhysicalKeyboardKey.numpad1 || PhysicalKeyboardKey.digit1 => KeypadKey.d1,
    PhysicalKeyboardKey.numpad2 || PhysicalKeyboardKey.digit2 => KeypadKey.d2,
    PhysicalKeyboardKey.numpad3 || PhysicalKeyboardKey.digit3 => KeypadKey.d3,
    PhysicalKeyboardKey.numpad4 || PhysicalKeyboardKey.digit4 => KeypadKey.d4,
    PhysicalKeyboardKey.numpad5 || PhysicalKeyboardKey.digit5 => KeypadKey.d5,
    PhysicalKeyboardKey.numpad6 || PhysicalKeyboardKey.digit6 => KeypadKey.d6,
    PhysicalKeyboardKey.numpad7 || PhysicalKeyboardKey.digit7 => KeypadKey.d7,
    PhysicalKeyboardKey.numpad8 || PhysicalKeyboardKey.digit8 => KeypadKey.d8,
    PhysicalKeyboardKey.numpad9 || PhysicalKeyboardKey.digit9 => KeypadKey.d9,
    PhysicalKeyboardKey.numpadEnter ||
    PhysicalKeyboardKey.enter => KeypadKey.enter,
    PhysicalKeyboardKey.numpadAdd => KeypadKey.plus,
    PhysicalKeyboardKey.numpadSubtract ||
    PhysicalKeyboardKey.minus => KeypadKey.minus,
    PhysicalKeyboardKey.numpadMultiply => KeypadKey.star,
    PhysicalKeyboardKey.numpadDecimal ||
    PhysicalKeyboardKey.period => KeypadKey.dot,
    PhysicalKeyboardKey.numpadDivide ||
    PhysicalKeyboardKey.slash => KeypadKey.slash,
    _ => null,
  };
}

/// Digit 0–9 for [key], or null if [key] is not a digit.
int? keypadDigit(KeypadKey key) {
  return switch (key) {
    KeypadKey.d0 => 0,
    KeypadKey.d1 => 1,
    KeypadKey.d2 => 2,
    KeypadKey.d3 => 3,
    KeypadKey.d4 => 4,
    KeypadKey.d5 => 5,
    KeypadKey.d6 => 6,
    KeypadKey.d7 => 7,
    KeypadKey.d8 => 8,
    KeypadKey.d9 => 9,
    KeypadKey.enter ||
    KeypadKey.plus ||
    KeypadKey.minus ||
    KeypadKey.star ||
    KeypadKey.dot ||
    KeypadKey.slash => null,
  };
}
