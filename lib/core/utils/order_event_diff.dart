import '../../models/kds_order_event.dart';
import '../../models/order_item_model.dart';
import '../../models/order_model.dart';

/// Chef-facing diffs between two snapshots of the same order.
///
/// [previous] null means the ticket just appeared on this device — only
/// [KdsOrderEventKind.newOrder] is returned (no type/item/generic extras).
///
/// Metadata-only changes (`version`, `updatedAt`, `completedAt`,
/// `isRemovedUnseen`) do not produce events, so a local optimistic mutation
/// followed by a matching server/WS echo yields an empty list.
List<KdsOrderEvent> diffOrderEvents(Order? previous, Order next) {
  if (previous == null) {
    return <KdsOrderEvent>[_event(next, KdsOrderEventKind.newOrder)];
  }

  final List<KdsOrderEvent> events = <KdsOrderEvent>[];

  if (previous.status != OrderStatus.cancelled &&
      next.status == OrderStatus.cancelled) {
    events.add(_event(next, KdsOrderEventKind.cancelled));
  }

  if (previous.type != next.type) {
    events.add(
      _event(
        next,
        KdsOrderEventKind.orderTypeChanged,
        previousType: previous.type,
        nextType: next.type,
      ),
    );
  }

  final Map<String, OrderItem> previousById = <String, OrderItem>{
    for (final OrderItem item in previous.items) item.id: item,
  };
  final Map<String, OrderItem> nextById = <String, OrderItem>{
    for (final OrderItem item in next.items) item.id: item,
  };

  for (final OrderItem previousItem in previous.items) {
    final OrderItem? nextItem = nextById[previousItem.id];
    if (nextItem == null) {
      events.add(
        _event(
          next,
          KdsOrderEventKind.itemRemoved,
          itemId: previousItem.id,
          itemName: previousItem.nameSnapshot,
        ),
      );
      continue;
    }
    // Reuse backend removal flags; missing-id (above) is the omit-style fallback.
    if (!previousItem.isRemoved && nextItem.isRemoved) {
      events.add(
        _event(
          next,
          KdsOrderEventKind.itemRemoved,
          itemId: nextItem.id,
          itemName: nextItem.nameSnapshot,
        ),
      );
      continue;
    }
    if (!previousItem.isRemoved &&
        !nextItem.isRemoved &&
        previousItem.quantity != nextItem.quantity) {
      events.add(
        _event(
          next,
          KdsOrderEventKind.itemQuantityChanged,
          itemId: nextItem.id,
          itemName: nextItem.nameSnapshot,
          oldQuantity: previousItem.quantity,
          newQuantity: nextItem.quantity,
        ),
      );
    }
  }

  for (final OrderItem nextItem in next.items) {
    if (previousById.containsKey(nextItem.id) || nextItem.isRemoved) {
      continue;
    }
    events.add(
      _event(
        next,
        KdsOrderEventKind.itemAdded,
        itemId: nextItem.id,
        itemName: nextItem.nameSnapshot,
      ),
    );
  }

  if (events.isEmpty && _hasChefVisibleChange(previous, next)) {
    events.add(_event(next, KdsOrderEventKind.genericUpdate));
  }

  return events;
}

KdsOrderEvent _event(
  Order order,
  KdsOrderEventKind kind, {
  String? itemId,
  String? itemName,
  int? oldQuantity,
  int? newQuantity,
  OrderType? previousType,
  OrderType? nextType,
}) {
  return KdsOrderEvent(
    kind: kind,
    orderId: order.id,
    displayNumber: order.displayNumber,
    kotNumber: order.kotNumber,
    stationId: order.stationId,
    type: order.type,
    tableNumber: order.tableNumber,
    itemId: itemId,
    itemName: itemName,
    oldQuantity: oldQuantity,
    newQuantity: newQuantity,
    previousType: previousType,
    nextType: nextType,
  );
}

bool _hasChefVisibleChange(Order previous, Order next) {
  if (previous.status != next.status ||
      previous.tableNumber != next.tableNumber ||
      previous.customerName != next.customerName ||
      previous.note != next.note) {
    return true;
  }

  final Map<String, OrderItem> previousById = <String, OrderItem>{
    for (final OrderItem item in previous.items) item.id: item,
  };
  for (final OrderItem nextItem in next.items) {
    final OrderItem? previousItem = previousById[nextItem.id];
    if (previousItem == null) {
      continue;
    }
    if (previousItem.isCompleted != nextItem.isCompleted ||
        previousItem.modifierText != nextItem.modifierText ||
        previousItem.note != nextItem.note ||
        previousItem.nameSnapshot != nextItem.nameSnapshot ||
        previousItem.isNew != nextItem.isNew) {
      return true;
    }
  }
  return false;
}
