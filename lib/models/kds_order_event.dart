import 'order_model.dart';

enum KdsOrderEventKind {
  newOrder,
  cancelled,
  itemAdded,
  itemRemoved,
  itemQuantityChanged,
  orderTypeChanged,
  genericUpdate,
}

/// One-shot chef-facing change detected from an order snapshot replace.
///
/// Optional item/type fields are set only when [kind] needs them. Not
/// persisted — a future announcer should consume these from a stream.
class KdsOrderEvent {
  const KdsOrderEvent({
    required this.kind,
    required this.orderId,
    required this.displayNumber,
    this.kotNumber,
    required this.stationId,
    required this.type,
    this.tableNumber,
    this.itemId,
    this.itemName,
    this.oldQuantity,
    this.newQuantity,
    this.previousType,
    this.nextType,
  });

  final KdsOrderEventKind kind;
  final String orderId;
  final String displayNumber;
  final String? kotNumber;
  final String stationId;
  final OrderType type;
  final String? tableNumber;
  final String? itemId;
  final String? itemName;
  final int? oldQuantity;
  final int? newQuantity;
  final OrderType? previousType;
  final OrderType? nextType;

  @override
  bool operator ==(Object other) {
    return other is KdsOrderEvent &&
        other.kind == kind &&
        other.orderId == orderId &&
        other.displayNumber == displayNumber &&
        other.kotNumber == kotNumber &&
        other.stationId == stationId &&
        other.type == type &&
        other.tableNumber == tableNumber &&
        other.itemId == itemId &&
        other.itemName == itemName &&
        other.oldQuantity == oldQuantity &&
        other.newQuantity == newQuantity &&
        other.previousType == previousType &&
        other.nextType == nextType;
  }

  @override
  int get hashCode => Object.hash(
        kind,
        orderId,
        displayNumber,
        kotNumber,
        stationId,
        type,
        tableNumber,
        itemId,
        itemName,
        oldQuantity,
        newQuantity,
        previousType,
        nextType,
      );
}
