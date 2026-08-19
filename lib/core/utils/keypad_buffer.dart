/// Discards a buffer whose last keystroke is older than [timeout] BEFORE
/// appending [digit], so `10` → pause → `8` yields `8`, never `108`.
///
/// Stale means strictly older than [timeout]: `now == digitsAt + timeout`
/// is still in-window and appends. [digitsAt] null starts a fresh buffer
/// (`discardedStale` is false). Extra digits past [maxLength] are ignored.
///
/// Never calls [DateTime.now] — the caller injects [now].
({String digits, bool discardedStale}) applyKeypadDigit({
  required String digits,
  required DateTime? digitsAt,
  required int digit,
  required DateTime now,
  required Duration timeout,
  required int maxLength,
}) {
  final bool discardedStale =
      digitsAt != null && now.difference(digitsAt) > timeout;
  final String base = digitsAt == null || discardedStale ? '' : digits;
  if (base.length >= maxLength) {
    return (digits: base, discardedStale: discardedStale);
  }
  return (digits: '$base$digit', discardedStale: discardedStale);
}

/// True when there is no flash, or [now] is at/after [flashUntil].
///
/// Never calls [DateTime.now] — the caller injects [now].
bool isKeypadFlashExpired({
  required DateTime? flashUntil,
  required DateTime now,
}) {
  if (flashUntil == null) {
    return true;
  }
  return !now.isBefore(flashUntil);
}
