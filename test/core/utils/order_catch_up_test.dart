import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/utils/order_catch_up.dart';
import 'package:order_master_kds/models/sync_result.dart';

void main() {
  final SyncResult empty = SyncResult(
    serverTime: DateTime.utc(2026, 8, 15),
    events: const <SyncEvent>[],
    nextCursor: 'cursor_42',
    requiresFullReload: false,
  );

  test('null cursor skips sync and refreshes', () async {
    int syncCalls = 0;
    int refreshCalls = 0;
    int applyCalls = 0;

    await catchUpOrders(
      cursor: null,
      syncSinceCursor: (String cursor) async {
        syncCalls++;
        return empty;
      },
      applySyncResult: (SyncResult result) async {
        applyCalls++;
      },
      refresh: () async {
        refreshCalls++;
      },
    );

    expect(syncCalls, 0);
    expect(applyCalls, 0);
    expect(refreshCalls, 1);
  });

  test('successful sync applies once', () async {
    int syncCalls = 0;
    int refreshCalls = 0;
    SyncResult? applied;

    await catchUpOrders(
      cursor: 'cursor_42',
      syncSinceCursor: (String cursor) async {
        syncCalls++;
        expect(cursor, 'cursor_42');
        return empty;
      },
      applySyncResult: (SyncResult result) async {
        applied = result;
      },
      refresh: () async {
        refreshCalls++;
      },
    );

    expect(syncCalls, 1);
    expect(applied, same(empty));
    expect(refreshCalls, 0);
  });

  test('retries then refreshes after persistent failure', () async {
    int syncCalls = 0;
    int refreshCalls = 0;
    int delays = 0;

    await catchUpOrders(
      cursor: 'cursor_42',
      syncSinceCursor: (String cursor) async {
        syncCalls++;
        throw StateError('sync down');
      },
      applySyncResult: (SyncResult result) async {},
      refresh: () async {
        refreshCalls++;
      },
      delay: (Duration duration) async {
        delays++;
        expect(duration, kOrderCatchUpRetryDelay);
      },
    );

    expect(syncCalls, kOrderCatchUpMaxAttempts);
    expect(delays, kOrderCatchUpMaxAttempts - 1);
    expect(refreshCalls, 1);
  });

  test('succeeds on a later attempt without refresh', () async {
    int syncCalls = 0;
    int refreshCalls = 0;

    await catchUpOrders(
      cursor: 'cursor_42',
      syncSinceCursor: (String cursor) async {
        syncCalls++;
        if (syncCalls < 2) {
          throw StateError('once');
        }
        return empty;
      },
      applySyncResult: (SyncResult result) async {},
      refresh: () async {
        refreshCalls++;
      },
      delay: (Duration duration) async {},
    );

    expect(syncCalls, 2);
    expect(refreshCalls, 0);
  });
}
