class OrderItem {
  const OrderItem({
    required this.id,
    required this.productId,
    required this.nameSnapshot,
    required this.quantity,
    this.modifierText,
    this.note,
    this.isCompleted = false,
  });

  final String id;
  final String productId;
  final String nameSnapshot;
  final int quantity;
  final String? modifierText;
  final String? note;
  final bool isCompleted;

  OrderItem copyWith({
    String? id,
    String? productId,
    String? nameSnapshot,
    int? quantity,
    String? modifierText,
    String? note,
    bool? isCompleted,
  }) {
    return OrderItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      nameSnapshot: nameSnapshot ?? this.nameSnapshot,
      quantity: quantity ?? this.quantity,
      modifierText: modifierText ?? this.modifierText,
      note: note ?? this.note,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
