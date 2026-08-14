import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../controllers/order_controller.dart';
import '../controllers/urgency_settings_controller.dart';
import '../core/constants/kds_timing.dart';
import '../core/utils/cancelled_cooking_visibility.dart';
import '../core/utils/order_column_packer.dart';
import '../core/utils/order_urgency.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../models/product_category_model.dart';
import '../models/product_model.dart';
import '../models/urgency_settings.dart';
import '../services/cancelled_display_preference_service.dart';
import '../services/product_quantity_list_preference_service.dart';
import '../services/theme_preference_service.dart';
import '../views/kitchen_display/prep_line.dart';
import 'kds_backend_providers.dart';

export '../controllers/order_controller.dart'
    show
        orderControllerProvider,
        orderEventsControllerProvider,
        orderEventsProvider;
export '../controllers/urgency_settings_controller.dart'
    show urgencySettingsProvider, urgencySettingsServiceProvider;
export '../controllers/voice_announcement_controller.dart'
    show
        announcementPreferenceServiceProvider,
        announcementsEnabledProvider,
        kdsTtsServiceProvider,
        orderUpdatePulsePreferenceServiceProvider,
        orderUpdatePulseSecondsProvider,
        orderUpdatePulseUntilProvider,
        voiceAnnouncementProvider;
export '../services/cancelled_display_preference_service.dart';
export 'kds_backend_providers.dart';
export 'server_config_providers.dart';

enum KdsTab { cooking, completed, cancelled }

class TabCounts {
  const TabCounts({
    required this.cooking,
    required this.completed,
    required this.cancelled,
  });

  final int cooking;
  final int completed;
  final int cancelled;
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

final StateProvider<KdsTab> selectedKdsTabProvider = StateProvider<KdsTab>(
  (Ref ref) => KdsTab.cooking,
);
final StateProvider<ThemeMode> themeModeProvider = StateProvider<ThemeMode>(
  (Ref ref) => ThemeMode.light,
);

final Provider<ProductQuantityListPreferenceService>
productQuantityListPreferenceServiceProvider =
    Provider<ProductQuantityListPreferenceService>(
      (Ref ref) => ProductQuantityListPreferenceService(),
    );

/// Product & quantity sidebar on the kitchen display. Default visible.
final StateProvider<bool> productQuantityListVisibleProvider =
    StateProvider<bool>((Ref ref) => true);

final Provider<CancelledDisplayPreferenceService>
cancelledDisplayPreferenceServiceProvider =
    Provider<CancelledDisplayPreferenceService>(
      (Ref ref) => CancelledDisplayPreferenceService(),
    );

final StateProvider<int> cancelledDisplaySecondsProvider = StateProvider<int>(
  (Ref ref) => KdsTiming.cancelledCookingDisplayDuration.inSeconds,
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
      final DateTime now = ref.watch(kdsClockProvider).value ?? DateTime.now();
      final Duration cancelledDisplay = Duration(
        seconds: ref.watch(cancelledDisplaySecondsProvider),
      );

      return orders.where((Order order) {
        if (stationId != null && order.stationId != stationId) {
          return false;
        }
        return switch (tab) {
          KdsTab.cooking => isVisibleOnCookingTab(
            order: order,
            now: now,
            cancelledDisplayDuration: cancelledDisplay,
          ),
          KdsTab.completed => order.status == OrderStatus.completed,
          KdsTab.cancelled => order.status == OrderStatus.cancelled,
        };
      }).toList();
    });

final Provider<TabCounts> tabCountsProvider = Provider<TabCounts>((Ref ref) {
  final String? stationId = ref.watch(selectedStationProvider);
  final List<Order> orders =
      ref.watch(orderControllerProvider).value ?? <Order>[];
  final DateTime now = ref.watch(kdsClockProvider).value ?? DateTime.now();
  final Duration cancelledDisplay = Duration(
    seconds: ref.watch(cancelledDisplaySecondsProvider),
  );

  int cooking = 0;
  int completed = 0;
  int cancelled = 0;
  for (final Order order in orders) {
    if (stationId != null && order.stationId != stationId) {
      continue;
    }
    if (order.status == OrderStatus.completed) {
      completed++;
    }
    if (order.status == OrderStatus.cancelled) {
      cancelled++;
    }
    if (isVisibleOnCookingTab(
      order: order,
      now: now,
      cancelledDisplayDuration: cancelledDisplay,
    )) {
      cooking++;
    }
  }
  return TabCounts(
    cooking: cooking,
    completed: completed,
    cancelled: cancelled,
  );
});

bool isActiveOrderForStation(Order order, String? stationId) {
  // Prep sidebar totals: in-progress work only (exclude completed + cancelled).
  return order.status != OrderStatus.completed &&
      order.status != OrderStatus.cancelled &&
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
  final int warningMinutes = ref.watch(
    urgencySettingsProvider.select(
      (UrgencySettings settings) => settings.warningMinutes,
    ),
  );
  final int criticalMinutes = ref.watch(
    urgencySettingsProvider.select(
      (UrgencySettings settings) => settings.criticalMinutes,
    ),
  );
  return urgencyForOrder(
    order,
    now,
    warningThreshold: Duration(minutes: warningMinutes),
    criticalThreshold: Duration(minutes: criticalMinutes),
  );
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
              item.isNew,
              item.isRemoved,
              item.isRemovedUnseen,
            );
          }),
        ),
      );
    }),
  );
}
