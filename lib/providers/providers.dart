import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../controllers/order_controller.dart';
import '../controllers/urgency_settings_controller.dart';
import '../core/constants/kds_timing.dart';
import '../core/utils/board_ticket_order.dart';
import '../core/utils/cancelled_cooking_visibility.dart';
import '../core/utils/order_column_packer.dart';
import '../core/utils/order_title_number.dart';
import '../core/utils/order_urgency.dart';
import '../models/item_quantity.dart';
import '../models/order_model.dart';
import '../models/product_category_model.dart';
import '../models/product_model.dart';
import '../models/urgency_settings.dart';
import '../services/cancelled_display_preference_service.dart';
import '../services/product_quantity_list_preference_service.dart';
import '../services/theme_preference_service.dart';
import '../views/kitchen_display/prep_line.dart';
import 'board_ticket_order_providers.dart';
import 'kds_backend_providers.dart';
import 'order_title_number_providers.dart';

export '../controllers/order_controller.dart'
    show
        orderControllerProvider,
        orderEventsControllerProvider,
        orderEventsProvider,
        staleLeftoverOrderIdsProvider;
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
export 'board_ticket_order_providers.dart';
export 'kds_backend_providers.dart';
export 'order_title_number_providers.dart';
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

final Provider<List<ItemQuantitySection>> itemQuantitiesProvider =
    Provider<List<ItemQuantitySection>>((Ref ref) {
      final String? stationId = ref.watch(selectedStationProvider);
      final List<Order> orders =
          ref.watch(orderControllerProvider).value ?? <Order>[];
      final List<Product> products = ref.watch(productsProvider);
      final List<ProductCategory> categories = ref.watch(
        productCategoriesProvider,
      );
      final OrderTitleNumberSource titleNumberSource = ref.watch(
        orderTitleNumberSourceProvider,
      );
      final Set<String> staleOrderIds = ref.watch(staleLeftoverOrderIdsProvider);

      return buildItemQuantitySections(
        orders: orders,
        stationId: stationId,
        products: products,
        categories: categories,
        titleNumber: (Order order) =>
            orderTitleNumber(order, titleNumberSource),
        isStaleLeftover: staleOrderIds.contains,
      );
    });

final itemPrepBreakdownProvider = Provider.family<List<PrepLine>, ItemGroupKey>((
  Ref ref,
  ItemGroupKey key,
) {
  final List<ItemQuantitySection> sections = ref.watch(itemQuantitiesProvider);
  for (final ItemQuantitySection section in sections) {
    for (final ItemQuantityEntry entry in section.entries) {
      if (entry.key == key) {
        return entry.contributors;
      }
    }
  }
  return const <PrepLine>[];
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

/// Timestamp each tab sorts tickets by.
DateTime Function(Order order) boardSortTimeFor(KdsTab tab) {
  return switch (tab) {
    KdsTab.cooking => (Order order) => order.createdAt,
    KdsTab.completed => (Order order) => order.completedAt ?? order.updatedAt,
    KdsTab.cancelled => (Order order) => order.cancelledAt ?? order.updatedAt,
  };
}

/// Visible tickets in board reading order (left-to-right, top-down).
///
/// Shares [sortOrdersForBoard] and [boardSortTimeFor] with
/// [packedOrderBoardProvider], so keypad stepping can never walk a different
/// sequence than the one on screen.
final Provider<List<Order>> boardOrderedOrdersProvider = Provider<List<Order>>((
  Ref ref,
) {
  final KdsTab tab = ref.watch(selectedKdsTabProvider);
  final BoardTicketOrder ticketOrder = ref.watch(boardTicketOrderProvider);
  return sortOrdersForBoard(
    orders: ref.watch(ordersForCurrentViewProvider),
    sortTime: boardSortTimeFor(tab),
    newestFirst: ticketOrder == BoardTicketOrder.newestFirst,
  );
});

final packedOrderBoardProvider =
    Provider.family<PackedOrderBoard, BoardLayoutConstraints>((
      Ref ref,
      BoardLayoutConstraints constraints,
    ) {
      // Fingerprint ignores isCompleted so item-done toggles do not repack.
      ref.watch(ordersForCurrentViewProvider.select(_packingFingerprint));
      final BoardTicketOrder ticketOrder = ref.watch(boardTicketOrderProvider);
      final KdsTab tab = ref.watch(selectedKdsTabProvider);
      final List<Order> orders = ref.read(ordersForCurrentViewProvider);
      return packOrderColumns(
        orders: orders,
        boardWidth: constraints.boardWidth,
        boardHeight: constraints.boardHeight,
        newestFirst: ticketOrder == BoardTicketOrder.newestFirst,
        sortTime: boardSortTimeFor(tab),
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
        order.completedAt,
        order.cancelledAt,
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
