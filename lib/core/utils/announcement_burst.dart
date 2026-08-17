import '../../models/kds_order_event.dart';
import 'order_announcement.dart';
import 'order_title_number.dart';

const Duration announcementBurstWindow = Duration(seconds: 2);
const int announcementBurstThreshold = 4;
const int announcementPendingCap = 3;

class TimedAnnouncementEvent {
  const TimedAnnouncementEvent({required this.event, required this.at});

  final KdsOrderEvent event;
  final DateTime at;
}

class AnnouncementBurstResult {
  const AnnouncementBurstResult({
    required this.pending,
    required this.recent,
    required this.enqueued,
    this.interrupt = false,
  });

  /// Waiting utterances after this event (not including currently speaking).
  final List<String> pending;

  /// Burst window to retain for the next call (empty after a collapse).
  final List<TimedAnnouncementEvent> recent;

  /// Newly accepted lines this call (what TTS should speak).
  final List<String> enqueued;

  /// Stop the native queue first (same-order upgrade or flood collapse).
  final bool interrupt;
}

/// Pure burst/cap policy. [now] and each event's [TimedAnnouncementEvent.at]
/// are injected — this function never calls [DateTime.now].
AnnouncementBurstResult applyAnnouncementBurst({
  required List<TimedAnnouncementEvent> recent,
  required TimedAnnouncementEvent incoming,
  required DateTime now,
  required List<String> pending,
  OrderTitleNumberSource titleNumberSource =
      OrderTitleNumberSource.displayNumber,
}) {
  final DateTime windowStart = now.subtract(announcementBurstWindow);
  final List<TimedAnnouncementEvent> inWindow = recent
      .where(
        (TimedAnnouncementEvent e) =>
            !e.at.isBefore(windowStart) && !e.at.isAfter(now),
      )
      .toList();

  // Cap is for a busy 2s queue, not the whole shift.
  final List<String> livePending =
      inWindow.isEmpty ? <String>[] : pending;

  final int existingIndex = inWindow.indexWhere(
    (TimedAnnouncementEvent e) => e.event.orderId == incoming.event.orderId,
  );

  late final List<TimedAnnouncementEvent> nextRecent;
  late final KdsOrderEvent toSpeak;
  final bool sameOrderReplace = existingIndex >= 0;
  if (sameOrderReplace) {
    final KdsOrderEvent current = inWindow[existingIndex].event;
    final KdsOrderEvent winner = _preferSameOrder(current, incoming.event);
    nextRecent = List<TimedAnnouncementEvent>.of(inWindow);
    nextRecent[existingIndex] = TimedAnnouncementEvent(
      event: winner,
      at: incoming.at,
    );
    if (announcementFor(winner, titleNumberSource: titleNumberSource) ==
            announcementFor(current, titleNumberSource: titleNumberSource) &&
        winner.kind == current.kind) {
      return AnnouncementBurstResult(
        pending: livePending,
        recent: nextRecent,
        enqueued: const <String>[],
      );
    }
    toSpeak = winner;
  } else {
    toSpeak = incoming.event;
    nextRecent = <TimedAnnouncementEvent>[...inWindow, incoming];
  }

  final int uniqueOrders = nextRecent
      .map((TimedAnnouncementEvent e) => e.event.orderId)
      .toSet()
      .length;

  if (uniqueOrders >= announcementBurstThreshold &&
      !skipsAnnouncementFloodSummary(toSpeak.kind)) {
    final String summary = burstSummaryLine(uniqueOrders);
    return AnnouncementBurstResult(
      pending: <String>[summary],
      recent: const <TimedAnnouncementEvent>[],
      enqueued: <String>[summary],
      interrupt: true,
    );
  }

  final String line = announcementFor(
    toSpeak,
    titleNumberSource: titleNumberSource,
  );
  if (isKitchenCriticalAnnouncement(toSpeak.kind)) {
    return AnnouncementBurstResult(
      pending: <String>[...livePending, line],
      recent: nextRecent,
      enqueued: <String>[line],
      interrupt: sameOrderReplace,
    );
  }

  return _enqueue(
    pending: livePending,
    next: line,
    recent: nextRecent,
    interrupt: sameOrderReplace,
  );
}

KdsOrderEvent _preferSameOrder(KdsOrderEvent current, KdsOrderEvent incoming) {
  final int currentPriority = announcementCoalescePriority(current.kind);
  final int incomingPriority = announcementCoalescePriority(incoming.kind);
  if (incomingPriority < currentPriority) {
    return incoming;
  }
  if (incomingPriority > currentPriority) {
    return current;
  }
  if (isKitchenCriticalAnnouncement(incoming.kind)) {
    return incoming;
  }
  return current;
}

bool isBurst({
  required List<DateTime> timestamps,
  required DateTime now,
}) {
  final DateTime windowStart = now.subtract(announcementBurstWindow);
  final int count = timestamps
      .where(
        (DateTime at) => !at.isBefore(windowStart) && !at.isAfter(now),
      )
      .length;
  return count >= announcementBurstThreshold;
}

List<String> enqueueWithCap(List<String> pending, String next) {
  if (pending.length < announcementPendingCap) {
    return <String>[...pending, next];
  }
  if (pending.isNotEmpty && pending.last == announcementOverflowLine) {
    return pending;
  }
  return <String>[
    ...pending.take(announcementPendingCap - 1),
    announcementOverflowLine,
  ];
}

AnnouncementBurstResult _enqueue({
  required List<String> pending,
  required String next,
  required List<TimedAnnouncementEvent> recent,
  bool interrupt = false,
}) {
  final List<String> nextPending = enqueueWithCap(pending, next);
  final List<String> enqueued;
  if (nextPending.length > pending.length) {
    enqueued = nextPending.sublist(pending.length);
  } else if (nextPending.length == pending.length &&
      nextPending.isNotEmpty &&
      pending.isNotEmpty &&
      nextPending.last != pending.last) {
    enqueued = <String>[nextPending.last];
  } else {
    enqueued = const <String>[];
  }
  return AnnouncementBurstResult(
    pending: nextPending,
    recent: recent,
    enqueued: enqueued,
    interrupt: interrupt && enqueued.isNotEmpty,
  );
}
