class OrderItem {
  OrderItem({
    required this.id,
    required this.productId,
    required this.nameSnapshot,
    required this.quantity,
    this.modifierText,
    this.note,
    this.isCompleted = false,
    String? sourceItemId,
    this.isNew = false,
    this.isRemoved = false,
    this.isRemovedUnseen = false,
    this.sortOrder = 0,
  }) : sourceItemId = sourceItemId ?? id;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      sourceItemId: json['sourceItemId'] as String? ?? json['id'] as String,
      productId: json['productId'] as String,
      nameSnapshot: json['nameSnapshot'] as String,
      // Backend may emit quantity as 1.0 (double); coerce via num.
      quantity: (json['quantity'] as num).toInt(),
      modifierText: json['modifierText'] as String?,
      note: json['note'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      isNew: json['isNew'] as bool? ?? false,
      isRemoved: json['isRemoved'] as bool? ?? false,
      isRemovedUnseen: json['isRemovedUnseen'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String sourceItemId;
  final String productId;
  final String nameSnapshot;
  final int quantity;
  final String? modifierText;
  final String? note;
  final bool isCompleted;
  final bool isNew;
  final bool isRemoved;
  final bool isRemovedUnseen;
  final int sortOrder;

  OrderItem copyWith({
    String? id,
    String? sourceItemId,
    String? productId,
    String? nameSnapshot,
    int? quantity,
    String? modifierText,
    String? note,
    bool? isCompleted,
    bool? isNew,
    bool? isRemoved,
    bool? isRemovedUnseen,
    int? sortOrder,
  }) {
    return OrderItem(
      id: id ?? this.id,
      sourceItemId: sourceItemId ?? this.sourceItemId,
      productId: productId ?? this.productId,
      nameSnapshot: nameSnapshot ?? this.nameSnapshot,
      quantity: quantity ?? this.quantity,
      modifierText: modifierText ?? this.modifierText,
      note: note ?? this.note,
      isCompleted: isCompleted ?? this.isCompleted,
      isNew: isNew ?? this.isNew,
      isRemoved: isRemoved ?? this.isRemoved,
      isRemovedUnseen: isRemovedUnseen ?? this.isRemovedUnseen,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
