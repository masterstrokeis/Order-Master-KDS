import '../../models/kds_order_event.dart';
import '../../models/order_model.dart';

String spokenOrderType(OrderType type) {
  return switch (type) {
    OrderType.dineIn => 'Dine-in',
    OrderType.takeOut => 'Takeaway',
    OrderType.delivery => 'Delivery',
  };
}

String announcementFor(KdsOrderEvent event) {
  final String type = spokenOrderType(event.type);
  final String number = event.displayNumber;
  return switch (event.kind) {
    KdsOrderEventKind.newOrder => '$type order $number, new order.',
    KdsOrderEventKind.cancelled => '$type order $number, order cancelled.',
    KdsOrderEventKind.itemAdded ||
    KdsOrderEventKind.itemRemoved ||
    KdsOrderEventKind.itemQuantityChanged ||
    KdsOrderEventKind.genericUpdate => '$type order $number, order updated.',
    KdsOrderEventKind.orderTypeChanged =>
      'Order $number changed from ${spokenOrderType(event.previousType ?? event.type)} to ${spokenOrderType(event.nextType ?? event.type)}.',
  };
}

/// One spoken event per order. Priority: new > cancelled > type-changed > updated.
List<KdsOrderEvent> coalesceAnnouncements(List<KdsOrderEvent> events) {
  final List<String> orderIds = <String>[];
  final Map<String, KdsOrderEvent> winnerByOrderId = <String, KdsOrderEvent>{};
  for (final KdsOrderEvent event in events) {
    final KdsOrderEvent? current = winnerByOrderId[event.orderId];
    if (current == null) {
      orderIds.add(event.orderId);
      winnerByOrderId[event.orderId] = event;
      continue;
    }
    if (announcementCoalescePriority(event.kind) <
        announcementCoalescePriority(current.kind)) {
      winnerByOrderId[event.orderId] = event;
    }
  }
  return <KdsOrderEvent>[
    for (final String orderId in orderIds) winnerByOrderId[orderId]!,
  ];
}

bool shouldPulseForEvent(KdsOrderEvent event) {
  return event.kind != KdsOrderEventKind.newOrder &&
      event.kind != KdsOrderEventKind.cancelled;
}

/// Lower is more important. Used by snapshot coalesce and same-order burst merge.
int announcementCoalescePriority(KdsOrderEventKind kind) {
  return switch (kind) {
    KdsOrderEventKind.newOrder => 0,
    KdsOrderEventKind.cancelled => 1,
    KdsOrderEventKind.orderTypeChanged => 2,
    KdsOrderEventKind.itemAdded ||
    KdsOrderEventKind.itemRemoved ||
    KdsOrderEventKind.itemQuantityChanged ||
    KdsOrderEventKind.genericUpdate => 3,
  };
}

bool isKitchenCriticalAnnouncement(KdsOrderEventKind kind) {
  return kind == KdsOrderEventKind.newOrder ||
      kind == KdsOrderEventKind.cancelled ||
      kind == KdsOrderEventKind.orderTypeChanged;
}

/// Cancel and type-change must never become a flood summary.
bool skipsAnnouncementFloodSummary(KdsOrderEventKind kind) {
  return kind == KdsOrderEventKind.cancelled ||
      kind == KdsOrderEventKind.orderTypeChanged;
}

String burstSummaryLine(int uniqueOrderCount) {
  if (uniqueOrderCount == 1) {
    return '1 order updated.';
  }
  return '$uniqueOrderCount orders updated.';
}

const String announcementOverflowLine = 'More order updates.';

const String testAnnouncementLine =
    'This is a test announcement, order 1, table 3.';
