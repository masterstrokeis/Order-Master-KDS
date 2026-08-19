import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/constants/kds_timing.dart';
import 'package:order_master_kds/core/utils/keypad_buffer.dart';

void main() {
  final DateTime t0 = DateTime.utc(2026, 8, 18, 12);

  test('appends within the timeout: 1 then 0 → 10', () {
    final ({String digits, bool discardedStale}) first = applyKeypadDigit(
      digits: '',
      digitsAt: null,
      digit: 1,
      now: t0,
      timeout: KdsTiming.keypadBufferTimeout,
      maxLength: 4,
    );
    expect(first.digits, '1');
    expect(first.discardedStale, isFalse);

    final ({String digits, bool discardedStale}) second = applyKeypadDigit(
      digits: first.digits,
      digitsAt: t0,
      digit: 0,
      now: t0.add(const Duration(milliseconds: 400)),
      timeout: KdsTiming.keypadBufferTimeout,
      maxLength: 4,
    );
    expect(second.digits, '10');
    expect(second.discardedStale, isFalse);
  });

  test('stale buffer is discarded BEFORE appending the new digit', () {
    // 10, wait > 2500ms, then 8 → 8, never 108.
    final ({String digits, bool discardedStale}) result = applyKeypadDigit(
      digits: '10',
      digitsAt: t0,
      digit: 8,
      now: t0.add(const Duration(seconds: 3)),
      timeout: KdsTiming.keypadBufferTimeout,
      maxLength: 4,
    );
    expect(result.digits, '8');
    expect(result.discardedStale, isTrue);
    expect(result.digits, isNot('108'));
  });

  test('exactly at the timeout boundary is still in-window and appends', () {
    // "Older than timeout" means strictly greater than 2500ms, so
    // now == digitsAt + timeout keeps the existing digits.
    final ({String digits, bool discardedStale}) result = applyKeypadDigit(
      digits: '10',
      digitsAt: t0,
      digit: 8,
      now: t0.add(KdsTiming.keypadBufferTimeout),
      timeout: KdsTiming.keypadBufferTimeout,
      maxLength: 4,
    );
    expect(result.discardedStale, isFalse);
    expect(result.digits, '108');
  });

  test('one millisecond past the timeout discards then appends', () {
    final ({String digits, bool discardedStale}) result = applyKeypadDigit(
      digits: '10',
      digitsAt: t0,
      digit: 8,
      now: t0.add(
        KdsTiming.keypadBufferTimeout + const Duration(milliseconds: 1),
      ),
      timeout: KdsTiming.keypadBufferTimeout,
      maxLength: 4,
    );
    expect(result.discardedStale, isTrue);
    expect(result.digits, '8');
  });

  test('max length 4 ignores extra digits', () {
    final ({String digits, bool discardedStale}) result = applyKeypadDigit(
      digits: '1234',
      digitsAt: t0,
      digit: 5,
      now: t0.add(const Duration(milliseconds: 100)),
      timeout: KdsTiming.keypadBufferTimeout,
      maxLength: 4,
    );
    expect(result.digits, '1234');
    expect(result.discardedStale, isFalse);
  });

  test('max length 2 ignores extra digits', () {
    final ({String digits, bool discardedStale}) result = applyKeypadDigit(
      digits: '12',
      digitsAt: t0,
      digit: 3,
      now: t0.add(const Duration(milliseconds: 100)),
      timeout: KdsTiming.keypadBufferTimeout,
      maxLength: 2,
    );
    expect(result.digits, '12');
    expect(result.discardedStale, isFalse);
  });

  test('stale buffer at max length still discards then appends', () {
    final ({String digits, bool discardedStale}) result = applyKeypadDigit(
      digits: '12',
      digitsAt: t0,
      digit: 8,
      now: t0.add(const Duration(seconds: 3)),
      timeout: KdsTiming.keypadBufferTimeout,
      maxLength: 2,
    );
    expect(result.digits, '8');
    expect(result.discardedStale, isTrue);
  });

  test('digitsAt null starts a fresh buffer', () {
    final ({String digits, bool discardedStale}) result = applyKeypadDigit(
      digits: '99',
      digitsAt: null,
      digit: 4,
      now: t0,
      timeout: KdsTiming.keypadBufferTimeout,
      maxLength: 4,
    );
    expect(result.digits, '4');
    expect(result.discardedStale, isFalse);
  });

  test('isKeypadFlashExpired uses injected now', () {
    expect(isKeypadFlashExpired(flashUntil: null, now: t0), isTrue);
    expect(
      isKeypadFlashExpired(
        flashUntil: t0.add(KdsTiming.keypadFlashDuration),
        now: t0,
      ),
      isFalse,
    );
    expect(
      isKeypadFlashExpired(
        flashUntil: t0.add(KdsTiming.keypadFlashDuration),
        now: t0.add(KdsTiming.keypadFlashDuration),
      ),
      isTrue,
    );
  });
}
