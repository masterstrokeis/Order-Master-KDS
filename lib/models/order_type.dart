enum OrderTypeKind { dineIn, delivery, takeOut, other }

/// Known POS types plus an [other] bucket that keeps the backend `type` string.
class OrderType {
  const OrderType._(this.kind, this.wireValue);

  static const OrderType dineIn = OrderType._(OrderTypeKind.dineIn, 'DINE-IN');
  static const OrderType delivery = OrderType._(
    OrderTypeKind.delivery,
    'DELIVERY',
  );
  static const OrderType takeOut = OrderType._(
    OrderTypeKind.takeOut,
    'TAKE AWAY',
  );

  factory OrderType.parse(String raw) {
    final String trimmed = raw.trim();
    switch (trimmed) {
      case 'dineIn':
        return dineIn;
      case 'takeOut':
        return takeOut;
      case 'delivery':
        return delivery;
    }

    final String key = trimmed.toUpperCase().replaceAll('_', ' ');
    return switch (key) {
      'DINE-IN' || 'DINE IN' || 'DINEIN' => dineIn,
      'TAKE AWAY' || 'TAKEAWAY' || 'TAKE-OUT' || 'TAKE OUT' || 'TAKEOUT' =>
        takeOut,
      'DELIVERY' => delivery,
      _ => OrderType._(
        OrderTypeKind.other,
        trimmed.isEmpty ? raw : trimmed,
      ),
    };
  }

  final OrderTypeKind kind;
  final String wireValue;

  String get displayLabel {
    return switch (kind) {
      OrderTypeKind.dineIn => 'Dine-In',
      OrderTypeKind.takeOut => 'Take Away',
      OrderTypeKind.delivery => 'Delivery',
      OrderTypeKind.other => wireValue,
    };
  }

  String serviceLabel({String? tableNumber}) {
    if (kind == OrderTypeKind.dineIn) {
      return 'Table - ${tableNumber ?? '--'}';
    }
    return displayLabel;
  }

  String get spokenLabel {
    return switch (kind) {
      OrderTypeKind.dineIn => 'Dine-in',
      OrderTypeKind.takeOut => 'Takeaway',
      OrderTypeKind.delivery => 'Delivery',
      OrderTypeKind.other => wireValue,
    };
  }

  @override
  bool operator ==(Object other) {
    if (other is! OrderType) {
      return false;
    }
    if (kind == OrderTypeKind.other) {
      return other.kind == OrderTypeKind.other && other.wireValue == wireValue;
    }
    return kind == other.kind;
  }

  @override
  int get hashCode {
    if (kind == OrderTypeKind.other) {
      return Object.hash(kind, wireValue);
    }
    return kind.hashCode;
  }
}
