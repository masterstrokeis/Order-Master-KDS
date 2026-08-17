import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/models/item_quantity.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/models/product_category_model.dart';
import 'package:order_master_kds/models/product_model.dart';
import 'package:order_master_kds/services/mock_orders_service.dart';

Order _order({
  required String id,
  required List<OrderItem> items,
  OrderStatus status = OrderStatus.cooking,
  String stationId = 'station-1',
  DateTime? createdAt,
}) {
  final DateTime at = createdAt ?? DateTime.utc(2026, 1, 1, 12);
  return Order(
    id: id,
    displayNumber: id,
    stationId: stationId,
    createdAt: at,
    type: OrderType.dineIn,
    status: status,
    tableNumber: '05',
    items: items,
  );
}

OrderItem _item({
  required String id,
  required String name,
  String productId = 'p-test',
  String? modifierText,
  int quantity = 1,
  bool isCompleted = false,
  bool isRemoved = false,
}) {
  return OrderItem(
    id: id,
    productId: productId,
    nameSnapshot: name,
    quantity: quantity,
    modifierText: modifierText,
    isCompleted: isCompleted,
    isRemoved: isRemoved,
  );
}

List<ItemQuantitySection> _build({
  required List<Order> orders,
  List<Product>? products,
  List<ProductCategory>? categories,
  String? stationId = 'station-1',
}) {
  final MockOrdersService mock = const MockOrdersService();
  return buildItemQuantitySections(
    orders: orders,
    stationId: stationId,
    products: products ?? mock.fetchProducts(),
    categories: categories ?? mock.fetchCategories(),
    titleNumber: (Order order) => order.displayNumber,
    isStaleLeftover: (_) => false,
  );
}

List<ItemQuantityEntry> _entries(List<ItemQuantitySection> sections) {
  return sections.expand((ItemQuantitySection s) => s.entries).toList();
}

ItemQuantityEntry? _findEntry(
  List<ItemQuantitySection> sections,
  ItemGroupKey key,
) {
  for (final ItemQuantityEntry entry in _entries(sections)) {
    if (entry.key == key) {
      return entry;
    }
  }
  return null;
}

void main() {
  test('same name with different modifiers produces separate rows', () {
    final List<ItemQuantitySection> sections = _build(
      orders: <Order>[
        _order(
          id: 'ord-1',
          items: <OrderItem>[
            _item(id: 'i1', name: 'Burger', modifierText: 'Medium'),
            _item(id: 'i2', name: 'Burger', modifierText: 'Well-done'),
          ],
        ),
      ],
    );

    final ItemQuantityEntry? medium = _findEntry(
      sections,
      const ItemGroupKey(name: 'Burger', modifierText: 'Medium'),
    );
    final ItemQuantityEntry? wellDone = _findEntry(
      sections,
      const ItemGroupKey(name: 'Burger', modifierText: 'Well-done'),
    );

    expect(medium?.quantity, 1);
    expect(wellDone?.quantity, 1);
    expect(medium?.key, isNot(equals(wellDone?.key)));
  });

  test('null, empty, and whitespace modifiers collapse to one group', () {
    final List<ItemQuantitySection> sections = _build(
      orders: <Order>[
        _order(
          id: 'ord-1',
          items: <OrderItem>[
            _item(id: 'i1', name: 'Burger'),
            _item(id: 'i2', name: 'Burger', modifierText: ''),
            _item(id: 'i3', name: 'Burger', modifierText: '   '),
          ],
        ),
      ],
    );

    final ItemQuantityEntry? entry = _findEntry(
      sections,
      const ItemGroupKey(name: 'Burger', modifierText: ''),
    );
    expect(entry?.quantity, 3);
    expect(_entries(sections), hasLength(1));
  });

  test('remaining quantity excludes completed and removed items', () {
    final List<ItemQuantitySection> sections = _build(
      orders: <Order>[
        _order(
          id: 'ord-1',
          items: <OrderItem>[
            _item(id: 'i1', name: 'Burger', quantity: 2),
            _item(id: 'i2', name: 'Burger', isCompleted: true),
            _item(id: 'i3', name: 'Burger', isRemoved: true),
          ],
        ),
      ],
    );

    expect(
      _findEntry(
        sections,
        const ItemGroupKey(name: 'Burger', modifierText: ''),
      )?.quantity,
      2,
    );
  });

  test('unknown productId still appears in flat list, not dropped', () {
    final List<ItemQuantitySection> sections = _build(
      orders: <Order>[
        _order(
          id: 'ord-1',
          items: <OrderItem>[
            _item(
              id: 'i1',
              name: 'Mystery Dish',
              productId: 'unknown-backend-id',
            ),
          ],
        ),
      ],
    );

    expect(sections, hasLength(1));
    expect(sections.first.category, flatSidebarCategory);
    expect(_entries(sections).single.key.name, 'Mystery Dish');
  });

  test('known catalog product still appears in flat list', () {
    final List<ItemQuantitySection> sections = _build(
      orders: <Order>[
        _order(
          id: 'ord-1',
          items: <OrderItem>[
            _item(
              id: 'i1',
              name: 'Botica Ceviche',
              productId: 'p-ceviche',
            ),
          ],
        ),
      ],
    );

    expect(_entries(sections), hasLength(1));
    expect(_entries(sections).single.key.name, 'Botica Ceviche');
    expect(_entries(sections).single.quantity, 1);
  });

  test('global FIFO orders rows by oldest pending ticket', () {
    final DateTime t1 = DateTime.utc(2026, 1, 1, 10);
    final DateTime t2 = DateTime.utc(2026, 1, 1, 11);
    final DateTime t3 = DateTime.utc(2026, 1, 1, 12);
    final DateTime t4 = DateTime.utc(2026, 1, 1, 13);

    final List<ItemQuantityEntry> entries = _entries(
      _build(
        orders: <Order>[
          _order(
            id: 'ord-coffee',
            createdAt: t4,
            items: <OrderItem>[_item(id: 'i4', name: 'Coffee', quantity: 5)],
          ),
          _order(
            id: 'ord-shawarma',
            createdAt: t1,
            items: <OrderItem>[
              _item(id: 'i1', name: 'Shawarma', quantity: 3),
            ],
          ),
          _order(
            id: 'ord-mango',
            createdAt: t2,
            items: <OrderItem>[
              _item(id: 'i2', name: 'Mango Juice', quantity: 2),
            ],
          ),
          _order(
            id: 'ord-tea',
            createdAt: t3,
            items: <OrderItem>[_item(id: 'i3', name: 'Tea')],
          ),
        ],
      ),
    );

    expect(
      entries.map((ItemQuantityEntry entry) => entry.key.name),
      <String>['Shawarma', 'Mango Juice', 'Tea', 'Coffee'],
    );
    expect(entries.first.firstSeenAt, t1);
    expect(entries.last.firstSeenAt, t4);
  });

  test('reappearing group sorts last after earlier groups', () {
    final DateTime t1 = DateTime.utc(2026, 1, 1, 10);
    final DateTime t2 = DateTime.utc(2026, 1, 1, 11);
    final DateTime t3 = DateTime.utc(2026, 1, 1, 12);
    final DateTime t4 = DateTime.utc(2026, 1, 1, 13);
    final DateTime t5 = DateTime.utc(2026, 1, 1, 14);

    final List<ItemQuantityEntry> afterReappear = _entries(
      _build(
        orders: <Order>[
          _order(
            id: 'ord-mango',
            createdAt: t2,
            items: <OrderItem>[
              _item(id: 'i2', name: 'Mango Juice', quantity: 2),
            ],
          ),
          _order(
            id: 'ord-tea',
            createdAt: t3,
            items: <OrderItem>[_item(id: 'i3', name: 'Tea')],
          ),
          _order(
            id: 'ord-coffee',
            createdAt: t4,
            items: <OrderItem>[_item(id: 'i4', name: 'Coffee', quantity: 5)],
          ),
          _order(
            id: 'ord-shawarma-new',
            createdAt: t5,
            items: <OrderItem>[_item(id: 'i5', name: 'Shawarma')],
          ),
        ],
      ),
    );

    expect(
      afterReappear.map((ItemQuantityEntry entry) => entry.key.name),
      <String>['Mango Juice', 'Tea', 'Coffee', 'Shawarma'],
    );
    expect(afterReappear.last.firstSeenAt, t5);

    // Contrast: when shawarma never left, it stays first.
    final List<ItemQuantityEntry> withOriginalShawarma = _entries(
      _build(
        orders: <Order>[
          _order(
            id: 'ord-shawarma',
            createdAt: t1,
            items: <OrderItem>[_item(id: 'i1', name: 'Shawarma', quantity: 3)],
          ),
          _order(
            id: 'ord-mango',
            createdAt: t2,
            items: <OrderItem>[
              _item(id: 'i2', name: 'Mango Juice', quantity: 2),
            ],
          ),
          _order(
            id: 'ord-tea',
            createdAt: t3,
            items: <OrderItem>[_item(id: 'i3', name: 'Tea')],
          ),
          _order(
            id: 'ord-coffee',
            createdAt: t3,
            items: <OrderItem>[_item(id: 'i4', name: 'Coffee', quantity: 5)],
          ),
        ],
      ),
    );
    expect(withOriginalShawarma.first.key.name, 'Shawarma');
  });

  test('partial completion keeps group sorted by oldest remaining ticket', () {
    final DateTime t1 = DateTime.utc(2026, 1, 1, 10);
    final DateTime t5 = DateTime.utc(2026, 1, 1, 14);

    final List<ItemQuantityEntry> entries = _entries(
      _build(
        orders: <Order>[
          _order(
            id: 'ord-shawarma-old',
            createdAt: t1,
            items: <OrderItem>[
              _item(id: 'i1', name: 'Shawarma', quantity: 2),
            ],
          ),
          _order(
            id: 'ord-shawarma-new',
            createdAt: t5,
            items: <OrderItem>[_item(id: 'i2', name: 'Shawarma')],
          ),
          _order(
            id: 'ord-coffee',
            createdAt: DateTime.utc(2026, 1, 1, 13),
            items: <OrderItem>[_item(id: 'i3', name: 'Coffee', quantity: 5)],
          ),
        ],
      ),
    );

    expect(entries.first.key.name, 'Shawarma');
    expect(entries.first.firstSeenAt, t1);
    expect(entries.last.key.name, 'Coffee');
  });

  test('tie-breaker falls back to name when firstSeenAt matches', () {
    final DateTime shared = DateTime.utc(2026, 1, 1, 12);

    final List<ItemQuantityEntry> entries = _entries(
      _build(
        orders: <Order>[
          _order(
            id: 'ord-z',
            createdAt: shared,
            items: <OrderItem>[_item(id: 'i1', name: 'Zucchini')],
          ),
          _order(
            id: 'ord-a',
            createdAt: shared,
            items: <OrderItem>[_item(id: 'i2', name: 'Apple')],
          ),
        ],
      ),
    );

    expect(
      entries.map((ItemQuantityEntry entry) => entry.key.name),
      <String>['Apple', 'Zucchini'],
    );
  });

  test('completed and cancelled orders are excluded from totals', () {
    final List<ItemQuantitySection> sections = _build(
      orders: <Order>[
        _order(
          id: 'ord-live',
          items: <OrderItem>[_item(id: 'i1', name: 'Live Burger')],
        ),
        _order(
          id: 'ord-done',
          status: OrderStatus.completed,
          items: <OrderItem>[_item(id: 'i2', name: 'Done Burger')],
        ),
        _order(
          id: 'ord-cancel',
          status: OrderStatus.cancelled,
          items: <OrderItem>[_item(id: 'i3', name: 'Cancelled Burger')],
        ),
      ],
    );

    final List<String> names = _entries(sections)
        .map((ItemQuantityEntry entry) => entry.key.name)
        .toList();
    expect(names, contains('Live Burger'));
    expect(names, isNot(contains('Done Burger')));
    expect(names, isNot(contains('Cancelled Burger')));
  });

  test('station filter excludes other stations', () {
    final List<ItemQuantitySection> sections = _build(
      orders: <Order>[
        _order(
          id: 'ord-1',
          stationId: 'station-1',
          items: <OrderItem>[_item(id: 'i1', name: 'Station One')],
        ),
        _order(
          id: 'ord-2',
          stationId: 'station-2',
          items: <OrderItem>[_item(id: 'i2', name: 'Station Two')],
        ),
      ],
      stationId: 'station-1',
    );

    final List<String> names = _entries(sections)
        .map((ItemQuantityEntry entry) => entry.key.name)
        .toList();
    expect(names, equals(<String>['Station One']));
  });
}
