import '../../models/sync_result.dart';
import 'kds_api_logger.dart';

const int kOrderCatchUpMaxAttempts = 3;
const Duration kOrderCatchUpRetryDelay = Duration(milliseconds: 400);

/// Incremental `/sync` with retries, then a full order list reload.
///
/// [cursor] null means we have no bookmark — skip `/sync` and [refresh].
Future<void> catchUpOrders({
  required String? cursor,
  required Future<SyncResult> Function(String cursor) syncSinceCursor,
  required Future<void> Function(SyncResult result) applySyncResult,
  required Future<void> Function() refresh,
  Future<void> Function(Duration delay) delay = _defaultDelay,
}) async {
  if (cursor == null || cursor.isEmpty) {
    await refresh();
    return;
  }

  Object? lastError;
  for (int attempt = 0; attempt < kOrderCatchUpMaxAttempts; attempt++) {
    try {
      final SyncResult result = await syncSinceCursor(cursor);
      await applySyncResult(result);
      return;
    } catch (error) {
      lastError = error;
      KdsApiLogger.websocket(
        'catch-up attempt ${attempt + 1}/$kOrderCatchUpMaxAttempts failed: $error',
      );
      if (attempt < kOrderCatchUpMaxAttempts - 1) {
        await delay(kOrderCatchUpRetryDelay);
      }
    }
  }

  KdsApiLogger.websocket(
    'catch-up failed after $kOrderCatchUpMaxAttempts attempts, '
    'full refresh: $lastError',
  );
  await refresh();
}

Future<void> _defaultDelay(Duration delay) => Future<void>.delayed(delay);
