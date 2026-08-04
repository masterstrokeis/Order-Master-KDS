import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../controllers/order_controller.dart';
import '../core/constants/kds_timing.dart';
import '../core/utils/order_column_packer.dart';
import '../core/utils/order_urgency.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../models/product_category_model.dart';
import '../models/product_model.dart';
import '../models/station_model.dart';
import '../services/mock_orders_service.dart';
import '../services/theme_preference_service.dart';
import '../views/kitchen_display/prep_line.dart';

enum KdsTab { cooking, completed }

class TabCounts {
  const TabCounts({required this.cooking, required this.completed});

  final int cooking;
  final int completed;
}

class ProductQuantityEntry {
  const ProductQuantityEntry({required this.product, required this.quantity});

  final Product product;
  final int quantity;
}

class ProductQuantitySection {
  const ProductQuantitySection({required this.category, required this.entries});

  final ProductCategory category;
  final List<ProductQuantityEntry> entries;
}

final Provider<MockOrdersService> mockOrdersServiceProvider =
    Provider<MockOrdersService>((Ref ref) => const MockOrdersService());

final Provider<List<Station>> stationsProvider = Provider<List<Station>>((
  Ref ref,
) {
  return ref.watch(mockOrdersServiceProvider).fetchStations();
});

final Provider<List<Product>> productsProvider = Provider<List<Product>>((
  Ref ref,
) {
  return ref.watch(mockOrdersServiceProvider).fetchProducts();
});

final Provider<List<ProductCategory>> productCategoriesProvider =
    Provider<List<ProductCategory>>((Ref ref) {
      return ref.watch(mockOrdersServiceProvider).fetchCategories();
    });

final StateProvider<KdsTab> selectedKdsTabProvider = StateProvider<KdsTab>(
  (Ref ref) => KdsTab.cooking,
);

final StateProvider<String?> selectedStationProvider = StateProvider<String?>((
  Ref ref,
) {
  final List<Station> stations = ref.watch(stationsProvider);
  return stations.isEmpty ? null : stations.first.id;
});

final StateProvider<ThemeMode> themeModeProvider = StateProvider<ThemeMode>(
  (Ref ref) => ThemeMode.light,
);

final Provider<ThemePreferenceService> themePreferenceServiceProvider =
    Provider<ThemePreferenceService>((Ref ref) => ThemePreferenceService());

final StreamProvider<DateTime> kdsClockProvider = StreamProvider<DateTime>((
  Ref ref,
) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    KdsTiming.clockTickInterval,
    (_) => DateTime.now(),
  );
});

final Provider<List<Order>> ordersForCurrentViewProvider =
    Provider<List<Order>>((Ref ref) {
      final KdsTab tab = ref.watch(selectedKdsTabProvider);
      final String? stationId = ref.watch(selectedStationProvider);
      final List<Order> orders =
          ref.watch(orderControllerProvider).value ?? <Order>[];

      return orders.where((Order order) {
        if (stationId != null && order.stationId != stationId) {
          return false;
        }
        return switch (tab) {
          KdsTab.cooking => order.status != OrderStatus.completed,
          KdsTab.completed => order.status == OrderStatus.completed,
        };
      }).toList();
    });

final Provider<TabCounts> tabCountsProvider = Provider<TabCounts>((Ref ref) {
  final String? stationId = ref.watch(selectedStationProvider);
  final List<Order> orders =
      ref.watch(orderControllerProvider).value ?? <Order>[];

  int cooking = 0;
  int completed = 0;
  for (final Order order in orders) {
    if (stationId != null && order.stationId != stationId) {
      continue;
    }
    if (order.status == OrderStatus.completed) {
      completed++;
    } else {
      cooking++;
    }
  }
  return TabCounts(cooking: cooking, completed: completed);
});

bool isActiveOrderForStation(Order order, String? stationId) {
  return order.status != OrderStatus.completed &&
      (stationId == null || order.stationId == stationId);
}

final Provider<List<ProductQuantitySection>> productQuantitiesProvider =
    Provider<List<ProductQuantitySection>>((Ref ref) {
      final String? stationId = ref.watch(selectedStationProvider);
      final List<Order> orders =
          ref.watch(orderControllerProvider).value ?? <Order>[];
      final List<Product> products = ref.watch(productsProvider);
      final List<ProductCategory> categories = ref.watch(
        productCategoriesProvider,
      );

      final Map<String, int> quantities = <String, int>{};
      for (final Order order in orders) {
        if (!isActiveOrderForStation(order, stationId)) {
          continue;
        }
        for (final OrderItem item in order.items) {
          quantities.update(
            item.productId,
            (int value) => value + item.quantity,
            ifAbsent: () => item.quantity,
          );
        }
      }

      final List<ProductCategory> sortedCategories =
          List<ProductCategory>.of(categories)..sort(
            (ProductCategory a, ProductCategory b) =>
                a.sortOrder.compareTo(b.sortOrder),
          );

      return sortedCategories
          .map((ProductCategory category) {
            final List<ProductQuantityEntry> entries = products
                .where((Product product) => product.categoryId == category.id)
                .map(
                  (Product product) => ProductQuantityEntry(
                    product: product,
                    quantity: quantities[product.id] ?? 0,
                  ),
                )
                .where((ProductQuantityEntry entry) => entry.quantity > 0)
                .toList();
            return ProductQuantitySection(category: category, entries: entries);
          })
          .where((ProductQuantitySection section) => section.entries.isNotEmpty)
          .toList();
    });

final productPrepBreakdownProvider = Provider.family<List<PrepLine>, String>((
  Ref ref,
  String productId,
) {
  final String? stationId = ref.watch(selectedStationProvider);
  final List<Order> orders =
      ref.watch(orderControllerProvider).value ?? <Order>[];

  final List<({int sourceIndex, Order order})> activeOrders =
      orders.indexed
          .where(
            ((int, Order) entry) =>
                isActiveOrderForStation(entry.$2, stationId),
          )
          .map(((int, Order) entry) => (sourceIndex: entry.$1, order: entry.$2))
          .toList()
        ..sort((a, b) {
          final int byCreatedAt = a.order.createdAt.compareTo(
            b.order.createdAt,
          );
          return byCreatedAt != 0
              ? byCreatedAt
              : a.sourceIndex.compareTo(b.sourceIndex);
        });

  final List<PrepLine> lines = <PrepLine>[];
  for (final ({int sourceIndex, Order order}) entry in activeOrders) {
    final Order order = entry.order;
    final String serviceLabel = switch (order.type) {
      OrderType.dineIn => 'Table - ${order.tableNumber ?? '--'}',
      OrderType.delivery => 'Delivery',
      OrderType.takeOut => 'Take-Out',
    };

    for (final OrderItem item in order.items) {
      if (item.productId != productId) {
        continue;
      }
      lines.add(
        PrepLine(
          orderId: order.id,
          displayNumber: order.displayNumber,
          orderType: order.type,
          serviceLabel: serviceLabel,
          customerName: order.customerName,
          quantity: item.quantity,
          modifierText: item.modifierText,
          note: item.note,
          createdAt: order.createdAt,
          productName: item.nameSnapshot,
        ),
      );
    }
  }
  return lines;
});

final orderByIdProvider = Provider.family<Order?, String>((
  Ref ref,
  String orderId,
) {
  final List<Order> orders =
      ref.watch(orderControllerProvider).value ?? <Order>[];
  for (final Order order in orders) {
    if (order.id == orderId) {
      return order;
    }
  }
  return null;
});

final orderUrgencyProvider = Provider.family<OrderUrgency, String>((
  Ref ref,
  String orderId,
) {
  final Order? order = ref.watch(orderByIdProvider(orderId));
  if (order == null) {
    return OrderUrgency.normal;
  }
  final DateTime now = ref.watch(kdsClockProvider).value ?? DateTime.now();
  return urgencyForOrder(order, now);
});

final packedOrderBoardProvider =
    Provider.family<PackedOrderBoard, BoardLayoutConstraints>((
      Ref ref,
      BoardLayoutConstraints constraints,
    ) {
      // Fingerprint ignores isCompleted so item-done toggles do not repack.
      ref.watch(ordersForCurrentViewProvider.select(_packingFingerprint));
      final List<Order> orders = ref.read(ordersForCurrentViewProvider);
      return packOrderColumns(
        orders: orders,
        boardWidth: constraints.boardWidth,
        boardHeight: constraints.boardHeight,
      );
    });

int _packingFingerprint(List<Order> orders) {
  return Object.hashAll(
    orders.map((Order order) {
      return Object.hash(
        order.id,
        order.displayNumber,
        order.stationId,
        order.createdAt,
        order.type,
        order.status,
        order.tableNumber,
        order.customerName,
        Object.hashAll(
          order.items.map((item) {
            return Object.hash(
              item.id,
              item.productId,
              item.nameSnapshot,
              item.quantity,
              item.modifierText,
              item.note,
            );
          }),
        ),
      );
    }),
  );
}
