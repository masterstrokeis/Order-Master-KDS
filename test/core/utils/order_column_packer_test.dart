import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/constants/kds_layout.dart';
import 'package:order_master_kds/core/utils/order_column_packer.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';

OrderItem _item({
  required String id,
  required String name,
  String? modifierText,
  String? note,
  bool isCompleted = false,
}) {
  return OrderItem(
    id: id,
    productId: 'p-$id',
    nameSnapshot: name,
    quantity: 1,
    modifierText: modifierText,
    note: note,
    isCompleted: isCompleted,
  );
}

Order _order({
  required String id,
  required List<OrderItem> items,
  DateTime? createdAt,
}) {
  return Order(
    id: id,
    displayNumber: id,
    stationId: 'station-1',
    createdAt: createdAt ?? DateTime(2026, 1, 1, 12),
    type: OrderType.dineIn,
    status: OrderStatus.newOrder,
    tableNumber: '05',
    customerName: 'Test Guest',
    items: items,
  );
}

void main() {
  group('estimateItemHeight ignores isCompleted', () {
    const double columnWidth = KdsLayout.minimumColumnWidth;

    test('name-only item', () {
      final OrderItem plain = _item(id: '1', name: 'Fried buffalo shrimp taco');
      final OrderItem done = plain.copyWith(isCompleted: true);
      expect(
        estimateItemHeight(plain, columnWidth),
        estimateItemHeight(done, columnWidth),
      );
    });

    test('item with wrapped modifier text', () {
      final OrderItem plain = _item(
        id: '2',
        name: 'Crispy pork belly',
        modifierText:
            'Slaw, hoisin sauce, picked onion, cilantro, extra long garnish list',
      );
      final OrderItem done = plain.copyWith(isCompleted: true);
      expect(
        estimateItemHeight(plain, columnWidth),
        estimateItemHeight(done, columnWidth),
      );
    });

    test('item with Note line', () {
      final OrderItem plain = _item(
        id: '3',
        name: 'Botica Ceviche',
        note: 'No onions',
      );
      final OrderItem done = plain.copyWith(isCompleted: true);
      expect(
        estimateItemHeight(plain, columnWidth),
        estimateItemHeight(done, columnWidth),
      );
    });

    test('item with both modifier and Note lines', () {
      final OrderItem plain = _item(
        id: '4',
        name: 'Botica Ceviche',
        modifierText:
            'Rock fish, cucumber, Fresno chili, tomato, red onion, corn, cilantro',
        note: 'No onions',
      );
      final OrderItem done = plain.copyWith(isCompleted: true);
      expect(
        estimateItemHeight(plain, columnWidth),
        estimateItemHeight(done, columnWidth),
      );
    });
  });

  test('packs a short order into a single primary final segment', () {
    final PackedOrderBoard board = packOrderColumns(
      orders: <Order>[
        _order(
          id: 'a',
          items: <OrderItem>[_item(id: '1', name: 'Soup')],
        ),
      ],
      boardWidth: 1200,
      boardHeight: 900,
    );

    expect(board.columns.first, hasLength(1));
    final CardSegment segment = board.columns.first.single;
    expect(segment.isPrimary, isTrue);
    expect(segment.isFinal, isTrue);
    expect(segment.showOutgoingContinued, isFalse);
    expect(board.unplacedOrderIds, isEmpty);
  });

  test('splits tall order into primary + continuation', () {
    final List<OrderItem> items = List<OrderItem>.generate(
      12,
      (int i) => _item(
        id: '$i',
        name: 'Long named kitchen item number $i for wrapping',
        modifierText: 'modifier line that also wraps for height $i',
        note: 'special note $i',
      ),
    );

    // Tall enough for the continuation column to finish the order.
    final PackedOrderBoard board = packOrderColumns(
      orders: <Order>[_order(id: 'tall', items: items)],
      boardWidth: KdsLayout.minimumColumnWidth * 3 + KdsLayout.cardGap * 2,
      boardHeight: 720,
    );

    final List<CardSegment> all = board.columns
        .expand((List<CardSegment> column) => column)
        .toList();
    expect(all.length, greaterThan(1));
    expect(all.first.isPrimary, isTrue);
    expect(all.first.showOutgoingContinued, isTrue);
    expect(all[1].showIncomingContinued, isTrue);
    expect(all.last.isFinal, isTrue);
    expect(board.unplacedOrderIds, isEmpty);
  });

  test('reports unplaced orders when board capacity is exhausted', () {
    final List<Order> orders = List<Order>.generate(
      20,
      (int i) => _order(
        id: 'o$i',
        createdAt: DateTime(2026, 1, 1, 12, i),
        items: List<OrderItem>.generate(
          10,
          (int j) => _item(
            id: 'o$i-$j',
            name: 'Item $j with enough text to take vertical space',
            modifierText: 'modifier $j',
            note: 'note $j',
          ),
        ),
      ),
    );

    final PackedOrderBoard board = packOrderColumns(
      orders: orders,
      boardWidth: KdsLayout.minimumColumnWidth * 2 + KdsLayout.cardGap,
      boardHeight: 500,
    );

    expect(board.unplacedOrderIds, isNotEmpty);
  });

  test('column count clamps between 1 and 5', () {
    expect(computeColumnCount(100), 1);
    expect(
      computeColumnCount(
        KdsLayout.minimumColumnWidth * 4 + KdsLayout.cardGap * 3,
      ),
      4,
    );
    expect(computeColumnCount(5000), KdsLayout.maxColumns);
  });
}
