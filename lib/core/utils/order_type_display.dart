import 'package:flutter/material.dart';

import '../../models/order_type.dart';

IconData orderTypeHeaderIcon(OrderType type) {
  return switch (type.kind) {
    OrderTypeKind.dineIn => Icons.table_restaurant,
    OrderTypeKind.delivery => Icons.delivery_dining,
    OrderTypeKind.takeOut => Icons.shopping_bag_outlined,
    OrderTypeKind.other => Icons.receipt_long_outlined,
  };
}

IconData orderTypePrepIcon(OrderType type) {
  return switch (type.kind) {
    OrderTypeKind.dineIn => Icons.table_restaurant_outlined,
    OrderTypeKind.delivery => Icons.delivery_dining_outlined,
    OrderTypeKind.takeOut => Icons.shopping_bag_outlined,
    OrderTypeKind.other => Icons.receipt_long_outlined,
  };
}

IconData orderTypeCustomerIcon(OrderType type) {
  return type.kind == OrderTypeKind.delivery
      ? Icons.two_wheeler
      : Icons.person;
}
