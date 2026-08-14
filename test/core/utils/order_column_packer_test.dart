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

    test('note uses bodyMd line height and grows with long text', () {
      final OrderItem noNote = _item(id: 'n0', name: 'Botica Ceviche');
      final OrderItem shortNote = _item(
        id: 'n1',
        name: 'Botica Ceviche',
        note: 'No onions',
      );
      final OrderItem longNote = _item(
        id: 'n2',
        name: 'Botica Ceviche',
        note: List<String>.filled(12, 'Allergy handle carefully extra ice').join(' '),
      );

      expect(
        estimateItemHeight(shortNote, columnWidth) -
            estimateItemHeight(noNote, columnWidth),
        KdsLayout.secondaryTextTopPadding + KdsLayout.noteLineHeight,
      );
      expect(KdsLayout.noteLineHeight, 24);
      expect(
        estimateItemHeight(longNote, columnWidth),
        greaterThan(estimateItemHeight(shortNote, columnWidth)),
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
      boardHeight: 960,
    );

    final List<CardSegment> all = board.columns
        .expand((List<CardSegment> column) => column)
        .toList();
    expect(all.length, greaterThan(1));
    expect(all.first.isPrimary, isTrue);
    expect(all.first.showOutgoingContinued, isTrue);
    expect(all[1].showIncomingContinued, isTrue);
    expect(all.last.isFinal, isTrue);
  });

  test('appends extra columns instead of dropping orders', () {
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

    const double boardWidth =
        KdsLayout.minimumColumnWidth * 2 + KdsLayout.cardGap;
    final PackedOrderBoard board = packOrderColumns(
      orders: orders,
      boardWidth: boardWidth,
      boardHeight: 500,
    );

    final int viewportCount = computeColumnCount(boardWidth);
    expect(board.columns.length, greaterThan(viewportCount));
    final Set<String> placedIds = board.columns
        .expand((List<CardSegment> column) => column)
        .map((CardSegment s) => s.orderId)
        .toSet();
    expect(placedIds, unorderedEquals(orders.map((Order o) => o.id)));
  });

  test('tall order continues past the viewport column count', () {
    final List<OrderItem> items = List<OrderItem>.generate(
      24,
      (int i) => _item(
        id: '$i',
        name: 'Long named kitchen item number $i for wrapping',
        modifierText: 'modifier line that also wraps for height $i',
        note: 'special note $i',
      ),
    );

    const double boardWidth = KdsLayout.minimumColumnWidth;
    final PackedOrderBoard board = packOrderColumns(
      orders: <Order>[_order(id: 'tall', items: items)],
      boardWidth: boardWidth,
      boardHeight: 400,
    );

    expect(computeColumnCount(boardWidth), 1);
    expect(board.columns.length, greaterThan(1));
    final List<CardSegment> placed = board.columns
        .expand((List<CardSegment> column) => column)
        .where((CardSegment s) => s.orderId == 'tall')
        .toList();
    expect(placed, isNotEmpty);
    expect(placed.first.isPrimary, isTrue);
    expect(placed.last.isFinal, isTrue);
    expect(placed.last.itemEndIndex, items.length);
  });

  test('moves second order to next column when first column is full', () {
    Order tallOrder(String id, DateTime createdAt) {
      return _order(
        id: id,
        createdAt: createdAt,
        items: <OrderItem>[
          _item(
            id: '$id-1',
            name:
                'BLUEBERRY BUBBLE TEA-BUBBLE TEA with extra long wrapping name',
            modifierText:
                'Large cup, oat milk, less sugar, extra pearls, whipped cream',
            note: 'Customer waiting at counter for pickup please prioritize',
          ),
          _item(
            id: '$id-2',
            name:
                'CARAMEL BUBBLE TEA-BUBBLE TEA with another wrapping product name',
            modifierText:
                'Hot drink, almond milk, caramel drizzle, no ice please',
            note: 'Allergy note: contains dairy and nuts handle carefully',
          ),
        ],
      );
    }

    final double boardWidth =
        KdsLayout.minimumColumnWidth * 3 + KdsLayout.cardGap * 2;
    final double columnWidth = computeColumnWidth(boardWidth, 3);

    final Order first = tallOrder('ord1', DateTime(2026, 1, 1, 8, 2));
    final double firstHeight = estimateSegmentHeight(
      order: first,
      itemStartIndex: 0,
      itemEndIndex: first.items.length,
      columnWidth: columnWidth,
      isPrimary: true,
      isFinal: true,
      showIncomingContinued: false,
      showOutgoingContinued: false,
    );

    // Board fits one card + small slack, but not two full cards.
    final double boardHeight = firstHeight + KdsLayout.cardGap + 20;

    final PackedOrderBoard board = packOrderColumns(
      orders: <Order>[
        first,
        tallOrder('ord2', DateTime(2026, 1, 1, 8, 6)),
      ],
      boardWidth: boardWidth,
      boardHeight: boardHeight,
    );

    expect(board.columns[0].map((CardSegment s) => s.orderId), <String>[
      'ord1',
    ]);
    expect(board.columns[1].map((CardSegment s) => s.orderId), <String>[
      'ord2',
    ]);
  });

  test('later order does not appear between parts of a split order', () {
    final List<OrderItem> tallItems = List<OrderItem>.generate(
      12,
      (int i) => _item(
        id: 't$i',
        name: 'Long named kitchen item number $i for wrapping',
        modifierText: 'modifier line that also wraps for height $i',
        note: 'special note $i',
      ),
    );
    final Order tall = _order(
      id: 'tall',
      createdAt: DateTime(2026, 1, 1, 8, 2),
      items: tallItems,
    );
    final Order short = _order(
      id: 'short',
      createdAt: DateTime(2026, 1, 1, 8, 6),
      items: <OrderItem>[_item(id: 's1', name: 'Soup')],
    );

    final PackedOrderBoard board = packOrderColumns(
      orders: <Order>[tall, short],
      boardWidth: KdsLayout.minimumColumnWidth * 3 + KdsLayout.cardGap * 2,
      boardHeight: 520,
    );

    final List<String> sequence = board.columns
        .expand((List<CardSegment> column) => column)
        .map((CardSegment s) => s.orderId)
        .toList();
    expect(sequence.where((String id) => id == 'tall'), isNotEmpty);
    expect(sequence.where((String id) => id == 'short'), isNotEmpty);

    final int firstTall = sequence.indexOf('tall');
    final int lastTall = sequence.lastIndexOf('tall');
    expect(sequence.sublist(firstTall, lastTall + 1), everyElement('tall'));
    expect(sequence.indexOf('short'), greaterThan(lastTall));
  });

  test('removed prefix increases estimated item height', () {
    const double columnWidth = KdsLayout.minimumColumnWidth;
    final OrderItem plain = _item(
      id: '1',
      name: 'CHICKEN BURGER-BURGERS',
    );
    final OrderItem removed = plain.copyWith(
      isRemoved: true,
      isRemovedUnseen: true,
    );
    expect(
      estimateItemHeight(removed, columnWidth),
      greaterThan(estimateItemHeight(plain, columnWidth)),
    );
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
