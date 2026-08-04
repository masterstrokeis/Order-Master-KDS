import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../services/mock_orders_service.dart';

class OrderController extends AsyncNotifier<List<Order>> {
  MockOrdersService get _service => const MockOrdersService();

  @override
  Future<List<Order>> build() {
    return _service.fetchOrders();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<Order>>();
    state = await AsyncValue.guard(_service.fetchOrders);
  }

  void startOrder(String orderId) {
    final List<Order>? orders = state.value;
    if (orders == null) {
      return;
    }

    state = AsyncData<List<Order>>(
      orders.map((Order order) {
        if (order.id != orderId || order.status != OrderStatus.newOrder) {
          return order;
        }
        return order.copyWith(status: OrderStatus.cooking);
      }).toList(),
    );
  }

  void completeOrder(String orderId) {
    final List<Order>? orders = state.value;
    if (orders == null) {
      return;
    }

    state = AsyncData<List<Order>>(
      orders.map((Order order) {
        if (order.id != orderId || order.status != OrderStatus.cooking) {
          return order;
        }
        return order.copyWith(status: OrderStatus.completed);
      }).toList(),
    );
  }

  /// Restores an accidentally completed order to in-progress cooking.
  /// Preserves item completion flags; no-op unless status is [OrderStatus.completed].
  void rollbackOrder(String orderId) {
    final List<Order>? orders = state.value;
    if (orders == null) {
      return;
    }

    state = AsyncData<List<Order>>(
      orders.map((Order order) {
        if (order.id != orderId || order.status != OrderStatus.completed) {
          return order;
        }
        return order.copyWith(status: OrderStatus.cooking);
      }).toList(),
    );
  }

  void toggleItemCompleted(String orderId, String itemId) {
    final List<Order>? orders = state.value;
    if (orders == null) {
      return;
    }

    state = AsyncData<List<Order>>(
      orders.map((Order order) {
        if (order.id != orderId || order.status != OrderStatus.cooking) {
          return order;
        }

        final List<OrderItem> updatedItems = order.items.map((OrderItem item) {
          if (item.id != itemId) {
            return item;
          }
          return item.copyWith(isCompleted: !item.isCompleted);
        }).toList();

        return order.copyWith(items: updatedItems);
      }).toList(),
    );
  }
}

final AsyncNotifierProvider<OrderController, List<Order>>
orderControllerProvider =
    AsyncNotifierProvider<OrderController, List<Order>>(OrderController.new);
