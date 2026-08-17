import '../views/kitchen_display/prep_line.dart';
import 'order_item_model.dart';
import 'order_model.dart';
import 'product_category_model.dart';
import 'product_model.dart';

/// Normalized grouping key: [nameSnapshot] + [modifierText] (exact combination).
///
/// Normalization:
/// - [name] = `nameSnapshot.trim()`
/// - [modifierText] = `(item.modifierText ?? '').trim()` — null, empty, and
///   whitespace-only modifiers are the same group
/// - Matching is case-sensitive after trim
/// - Internal whitespace is preserved (`"Well done"` ≠ `"Well-done"`)
class ItemGroupKey {
  const ItemGroupKey({required this.name, required this.modifierText});

  factory ItemGroupKey.fromItem(OrderItem item) {
    return ItemGroupKey(
      name: item.nameSnapshot.trim(),
      modifierText: (item.modifierText ?? '').trim(),
    );
  }

  final String name;
  final String modifierText;

  /// Sidebar / panel title: name, with modifier appended when non-empty.
  String get displayTitle =>
      modifierText.isEmpty ? name : '$name ($modifierText)';

  @override
  bool operator ==(Object other) {
    return other is ItemGroupKey &&
        other.name == name &&
        other.modifierText == modifierText;
  }

  @override
  int get hashCode => Object.hash(name, modifierText);
}

/// One aggregated remaining-qty row in the items sidebar.
class ItemQuantityEntry {
  const ItemQuantityEntry({
    required this.key,
    required this.quantity,
    required this.contributors,
    required this.firstSeenAt,
  });

  final ItemGroupKey key;
  final int quantity;
  final List<PrepLine> contributors;

  /// Oldest contributing ticket time among remaining lines in this group.
  final DateTime firstSeenAt;
}

/// Wrapper for the flat sidebar list (single section; category not shown).
class ItemQuantitySection {
  const ItemQuantitySection({required this.category, required this.entries});

  final ProductCategory category;
  final List<ItemQuantityEntry> entries;
}

/// Sentinel category for the global flat sidebar section (not displayed).
const ProductCategory flatSidebarCategory = ProductCategory(
  id: '__flat__',
  name: '',
  sortOrder: 0,
);

/// Aggregates remaining item quantities from active station orders.
///
/// Only counts items where `!isCompleted && !isRemoved` on orders that pass
/// [isActiveOrderForStation].
///
/// Sidebar rows are sorted globally by [ItemQuantityEntry.firstSeenAt]
/// ascending (oldest pending ticket first). Tie-breaker: item name, then
/// modifier (case-insensitive). A group that drops to zero and reappears on a
/// new order sorts by that new ticket's time (typically last).
List<ItemQuantitySection> buildItemQuantitySections({
  required List<Order> orders,
  required String? stationId,
  required List<Product> products,
  required List<ProductCategory> categories,
  required String Function(Order order) titleNumber,
  required bool Function(String orderId) isStaleLeftover,
}) {
  final List<({int sourceIndex, Order order})> activeOrders =
      orders.indexed
          .where(
            ((int, Order) entry) => isActiveOrderForStation(entry.$2, stationId),
          )
          .map(((int, Order) entry) => (sourceIndex: entry.$1, order: entry.$2))
          .toList()
        ..sort((a, b) {
          final int byCreatedAt = a.order.createdAt.compareTo(b.order.createdAt);
          return byCreatedAt != 0
              ? byCreatedAt
              : a.sourceIndex.compareTo(b.sourceIndex);
        });

  final Map<ItemGroupKey, _MutableItemGroup> groups =
      <ItemGroupKey, _MutableItemGroup>{};

  for (final ({int sourceIndex, Order order}) entry in activeOrders) {
    final Order order = entry.order;
    final String serviceLabel = order.type.serviceLabel(
      tableNumber: order.tableNumber,
    );
    final bool canComplete =
        (order.status == OrderStatus.cooking ||
            order.status == OrderStatus.newOrder) &&
        !isStaleLeftover(order.id);

    for (final OrderItem item in order.items) {
      if (item.isCompleted || item.isRemoved) {
        continue;
      }

      final ItemGroupKey key = ItemGroupKey.fromItem(item);
      final _MutableItemGroup group = groups.putIfAbsent(
        key,
        () => _MutableItemGroup(key: key),
      );

      group.quantity += item.quantity;
      group.contributors.add(
        PrepLine(
          orderId: order.id,
          itemId: item.id,
          displayNumber: titleNumber(order),
          orderType: order.type,
          serviceLabel: serviceLabel,
          customerName: order.customerName,
          quantity: item.quantity,
          modifierText: item.modifierText,
          note: item.note,
          createdAt: order.createdAt,
          productName: item.nameSnapshot,
          canComplete: canComplete && !item.isRemoved,
          isCompleted: item.isCompleted,
        ),
      );
    }
  }

  if (groups.isEmpty) {
    return const <ItemQuantitySection>[];
  }

  final List<ItemQuantityEntry> entries = groups.values
      .where((_MutableItemGroup group) => group.quantity > 0)
      .map(_toEntry)
      .toList();
  _sortEntriesByFirstSeen(entries);

  return <ItemQuantitySection>[
    ItemQuantitySection(category: flatSidebarCategory, entries: entries),
  ];
}

ItemQuantityEntry _toEntry(_MutableItemGroup group) {
  return ItemQuantityEntry(
    key: group.key,
    quantity: group.quantity,
    contributors: List<PrepLine>.of(group.contributors),
    firstSeenAt: group.contributors
        .map((PrepLine line) => line.createdAt)
        .reduce(
          (DateTime earliest, DateTime next) =>
              next.isBefore(earliest) ? next : earliest,
        ),
  );
}

void _sortEntriesByFirstSeen(List<ItemQuantityEntry> entries) {
  entries.sort((ItemQuantityEntry a, ItemQuantityEntry b) {
    final int byFirstSeen = a.firstSeenAt.compareTo(b.firstSeenAt);
    if (byFirstSeen != 0) {
      return byFirstSeen;
    }
    final int byName = a.key.name.toLowerCase().compareTo(
      b.key.name.toLowerCase(),
    );
    if (byName != 0) {
      return byName;
    }
    return a.key.modifierText.toLowerCase().compareTo(
      b.key.modifierText.toLowerCase(),
    );
  });
}

class _MutableItemGroup {
  _MutableItemGroup({required this.key});

  final ItemGroupKey key;
  int quantity = 0;
  final List<PrepLine> contributors = <PrepLine>[];
}

/// Prep sidebar totals: in-progress work only (exclude completed + cancelled).
bool isActiveOrderForStation(Order order, String? stationId) {
  return order.status != OrderStatus.completed &&
      order.status != OrderStatus.cancelled &&
      (stationId == null || order.stationId == stationId);
}
