import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../models/product_category_model.dart';
import '../models/product_model.dart';
import '../models/station_model.dart';

class MockOrdersService {
  const MockOrdersService();

  List<Station> fetchStations() => const <Station>[
    Station(id: 'station-1', name: 'Cooking Station - 1', displayOrder: 1),
    Station(id: 'station-2', name: 'Cooking Station - 2', displayOrder: 2),
  ];

  List<ProductCategory> fetchCategories() => const <ProductCategory>[
    ProductCategory(id: 'seafoods', name: 'SEAFOODS', sortOrder: 1),
    ProductCategory(id: 'soups', name: 'SOUPS', sortOrder: 2),
    ProductCategory(id: 'salads', name: 'SALADS', sortOrder: 3),
  ];

  List<Product> fetchProducts() => const <Product>[
    Product(id: 'p-salmon-grill', name: 'Salmon Grill', categoryId: 'seafoods'),
    Product(id: 'p-miso-salmon', name: 'Miso Salmon', categoryId: 'seafoods'),
    Product(id: 'p-sea-bass', name: 'Sea Bass Grill', categoryId: 'seafoods'),
    Product(
      id: 'p-calamari',
      name: 'Grilled Calamari',
      categoryId: 'seafoods',
    ),
    Product(id: 'p-bisque', name: 'Lobster Bisque', categoryId: 'soups'),
    Product(id: 'p-tomato', name: 'Tomato Soup', categoryId: 'soups'),
    Product(id: 'p-caesar', name: 'Caesar Salad', categoryId: 'salads'),
    Product(
      id: 'p-carrot',
      name: 'Spicy Carrot Salad',
      categoryId: 'salads',
    ),
    Product(
      id: 'p-sushi-salad',
      name: 'Salmon Sushi Salad',
      categoryId: 'salads',
    ),
    Product(id: 'p-quinoa', name: 'Quinoa Salad', categoryId: 'salads'),
    Product(
      id: 'p-shrimp-taco',
      name: 'Fried buffalo shrimp taco',
      categoryId: 'seafoods',
    ),
    Product(
      id: 'p-diabla',
      name: 'Camarones A LA Diabla',
      categoryId: 'seafoods',
    ),
    Product(
      id: 'p-pork',
      name: 'Crispy pork belly',
      categoryId: 'seafoods',
    ),
    Product(id: 'p-ceviche', name: 'Botica Ceviche', categoryId: 'seafoods'),
  ];

  Future<List<Order>> fetchOrders({DateTime? now}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final DateTime reference = now ?? DateTime.now();
    return _buildOrders(reference);
  }

  List<Order> _buildOrders(DateTime now) {
    OrderItem item({
      required String id,
      required String productId,
      required String name,
      String? modifierText,
      String? note,
      bool isCompleted = false,
    }) {
      return OrderItem(
        id: id,
        productId: productId,
        nameSnapshot: name,
        quantity: 1,
        modifierText: modifierText,
        note: note,
        isCompleted: isCompleted,
      );
    }

    const String porkMods =
        'Slaw, hoisin sauce, picked onion, cilantro';
    const String cevicheMods =
        'Rock fish, cucumber, Fresno chili, tomato, red onion, corn, cilantro';

    return <Order>[
      Order(
        id: 'order-1',
        displayNumber: '356789',
        stationId: 'station-1',
        createdAt: now.subtract(const Duration(minutes: 4)),
        type: OrderType.dineIn,
        status: OrderStatus.newOrder,
        tableNumber: '05',
        customerName: 'Brownie Jennifer',
        items: <OrderItem>[
          item(
            id: 'o1-i1',
            productId: 'p-shrimp-taco',
            name: 'Fried buffalo shrimp taco',
          ),
          item(
            id: 'o1-i2',
            productId: 'p-diabla',
            name: 'Camarones A LA Diabla',
          ),
          item(
            id: 'o1-i3',
            productId: 'p-pork',
            name: 'Crispy pork belly',
            modifierText: porkMods,
          ),
          item(
            id: 'o1-i4',
            productId: 'p-diabla',
            name: 'Camarones A LA Diabla',
          ),
          item(
            id: 'o1-i5',
            productId: 'p-ceviche',
            name: 'Botica Ceviche',
          ),
          item(
            id: 'o1-i6',
            productId: 'p-pork',
            name: 'Crispy pork belly',
            modifierText: porkMods,
          ),
          item(
            id: 'o1-i7',
            productId: 'p-shrimp-taco',
            name: 'Fried buffalo shrimp taco',
          ),
          item(
            id: 'o1-i8',
            productId: 'p-ceviche',
            name: 'Botica Ceviche',
          ),
          item(
            id: 'o1-i9',
            productId: 'p-diabla',
            name: 'Camarones A LA Diabla',
          ),
        ],
      ),
      Order(
        id: 'order-2',
        displayNumber: '356790',
        stationId: 'station-1',
        createdAt: now.subtract(const Duration(minutes: 12)),
        type: OrderType.delivery,
        status: OrderStatus.newOrder,
        customerName: 'Jefferey Thomas',
        items: <OrderItem>[
          item(
            id: 'o2-i1',
            productId: 'p-shrimp-taco',
            name: 'Fried buffalo shrimp taco',
          ),
          item(
            id: 'o2-i2',
            productId: 'p-diabla',
            name: 'Camarones A LA Diabla',
          ),
          item(
            id: 'o2-i3',
            productId: 'p-shrimp-taco',
            name: 'Fried buffalo shrimp taco',
          ),
          item(
            id: 'o2-i4',
            productId: 'p-ceviche',
            name: 'Botica Ceviche',
          ),
          item(
            id: 'o2-i5',
            productId: 'p-diabla',
            name: 'Camarones A LA Diabla',
          ),
        ],
      ),
      Order(
        id: 'order-3',
        displayNumber: '356791',
        stationId: 'station-1',
        createdAt: now.subtract(const Duration(minutes: 16)),
        type: OrderType.dineIn,
        status: OrderStatus.newOrder,
        tableNumber: '06',
        customerName: 'Brownie Jennifer',
        items: <OrderItem>[
          item(
            id: 'o3-i1',
            productId: 'p-shrimp-taco',
            name: 'Fried buffalo shrimp taco',
          ),
          item(
            id: 'o3-i2',
            productId: 'p-diabla',
            name: 'Camarones A LA Diabla',
          ),
          item(
            id: 'o3-i3',
            productId: 'p-ceviche',
            name: 'Botica Ceviche',
            modifierText: cevicheMods,
            note: 'No onions',
          ),
          item(
            id: 'o3-i4',
            productId: 'p-pork',
            name: 'Crispy pork belly',
            modifierText: porkMods,
          ),
        ],
      ),
      Order(
        id: 'order-4',
        displayNumber: '356792',
        stationId: 'station-1',
        createdAt: now.subtract(const Duration(minutes: 8)),
        type: OrderType.delivery,
        status: OrderStatus.cooking,
        customerName: 'Jefferey Thomas',
        items: <OrderItem>[
          item(
            id: 'o4-i1',
            productId: 'p-shrimp-taco',
            name: 'Fried buffalo shrimp taco',
            isCompleted: true,
          ),
          item(
            id: 'o4-i2',
            productId: 'p-diabla',
            name: 'Camarones A LA Diabla',
          ),
          item(
            id: 'o4-i3',
            productId: 'p-ceviche',
            name: 'Botica Ceviche',
            modifierText: cevicheMods,
            note: 'No onions',
          ),
          item(
            id: 'o4-i4',
            productId: 'p-pork',
            name: 'Crispy pork belly',
            modifierText: porkMods,
          ),
        ],
      ),
      Order(
        id: 'order-5',
        displayNumber: '356793',
        stationId: 'station-1',
        createdAt: now.subtract(const Duration(minutes: 18)),
        type: OrderType.dineIn,
        status: OrderStatus.cooking,
        tableNumber: '05',
        customerName: 'Brownie Jennifer',
        items: <OrderItem>[
          item(
            id: 'o5-i1',
            productId: 'p-shrimp-taco',
            name: 'Fried buffalo shrimp taco',
          ),
          item(
            id: 'o5-i2',
            productId: 'p-diabla',
            name: 'Camarones A LA Diabla',
          ),
          item(
            id: 'o5-i3',
            productId: 'p-pork',
            name: 'Crispy pork belly',
            modifierText: porkMods,
          ),
          item(
            id: 'o5-i4',
            productId: 'p-diabla',
            name: 'Camarones A LA Diabla',
          ),
          item(
            id: 'o5-i5',
            productId: 'p-ceviche',
            name: 'Botica Ceviche',
          ),
          item(
            id: 'o5-i6',
            productId: 'p-shrimp-taco',
            name: 'Fried buffalo shrimp taco',
          ),
          item(
            id: 'o5-i7',
            productId: 'p-ceviche',
            name: 'Botica Ceviche',
          ),
          item(
            id: 'o5-i8',
            productId: 'p-diabla',
            name: 'Camarones A LA Diabla',
          ),
          item(
            id: 'o5-i9',
            productId: 'p-shrimp-taco',
            name: 'Fried buffalo shrimp taco',
          ),
          item(
            id: 'o5-i10',
            productId: 'p-diabla',
            name: 'Camarones A LA Diabla',
          ),
          item(
            id: 'o5-i11',
            productId: 'p-pork',
            name: 'Crispy pork belly',
            modifierText: porkMods,
          ),
          item(
            id: 'o5-i12',
            productId: 'p-diabla',
            name: 'Camarones A LA Diabla',
          ),
          item(
            id: 'o5-i13',
            productId: 'p-ceviche',
            name: 'Botica Ceviche',
            modifierText: cevicheMods,
            note: 'No onions',
          ),
          item(
            id: 'o5-i14',
            productId: 'p-pork',
            name: 'Crispy pork belly',
            modifierText: porkMods,
          ),
        ],
      ),
      Order(
        id: 'order-6',
        displayNumber: '356794',
        stationId: 'station-1',
        createdAt: now.subtract(const Duration(minutes: 6)),
        type: OrderType.takeOut,
        status: OrderStatus.newOrder,
        customerName: 'Nick Jerome',
        items: <OrderItem>[
          item(
            id: 'o6-i1',
            productId: 'p-shrimp-taco',
            name: 'Fried buffalo shrimp taco',
          ),
          item(
            id: 'o6-i2',
            productId: 'p-diabla',
            name: 'Camarones A LA Diabla',
          ),
          item(
            id: 'o6-i3',
            productId: 'p-salmon-grill',
            name: 'Salmon Grill',
          ),
          item(
            id: 'o6-i4',
            productId: 'p-miso-salmon',
            name: 'Miso Salmon',
          ),
          item(id: 'o6-i5', productId: 'p-sea-bass', name: 'Sea Bass Grill'),
          item(id: 'o6-i6', productId: 'p-calamari', name: 'Grilled Calamari'),
          item(id: 'o6-i7', productId: 'p-bisque', name: 'Lobster Bisque'),
          item(id: 'o6-i8', productId: 'p-tomato', name: 'Tomato Soup'),
          item(id: 'o6-i9', productId: 'p-caesar', name: 'Caesar Salad'),
        ],
      ),
      Order(
        id: 'order-7',
        displayNumber: '356795',
        stationId: 'station-1',
        createdAt: now.subtract(const Duration(minutes: 3)),
        type: OrderType.dineIn,
        status: OrderStatus.newOrder,
        tableNumber: '12',
        customerName: 'Alex Rivera',
        items: <OrderItem>[
          item(id: 'o7-i1', productId: 'p-carrot', name: 'Spicy Carrot Salad'),
          item(
            id: 'o7-i2',
            productId: 'p-sushi-salad',
            name: 'Salmon Sushi Salad',
          ),
          item(id: 'o7-i3', productId: 'p-quinoa', name: 'Quinoa Salad'),
          item(id: 'o7-i4', productId: 'p-caesar', name: 'Caesar Salad'),
        ],
      ),
      Order(
        id: 'order-8',
        displayNumber: '356796',
        stationId: 'station-1',
        createdAt: now.subtract(const Duration(minutes: 2)),
        type: OrderType.takeOut,
        status: OrderStatus.cooking,
        customerName: 'Sam Lee',
        items: <OrderItem>[
          item(id: 'o8-i1', productId: 'p-bisque', name: 'Lobster Bisque'),
          item(id: 'o8-i2', productId: 'p-tomato', name: 'Tomato Soup'),
          item(
            id: 'o8-i3',
            productId: 'p-salmon-grill',
            name: 'Salmon Grill',
          ),
        ],
      ),
      // Completed tab sample
      Order(
        id: 'order-9',
        displayNumber: '356700',
        stationId: 'station-1',
        createdAt: now.subtract(const Duration(minutes: 40)),
        type: OrderType.dineIn,
        status: OrderStatus.completed,
        tableNumber: '03',
        customerName: 'Taylor Swift',
        items: <OrderItem>[
          item(
            id: 'o9-i1',
            productId: 'p-caesar',
            name: 'Caesar Salad',
            isCompleted: true,
          ),
          item(
            id: 'o9-i2',
            productId: 'p-tomato',
            name: 'Tomato Soup',
            isCompleted: true,
          ),
        ],
      ),
      Order(
        id: 'order-10',
        displayNumber: '356701',
        stationId: 'station-1',
        createdAt: now.subtract(const Duration(minutes: 35)),
        type: OrderType.delivery,
        status: OrderStatus.completed,
        customerName: 'Jamie Fox',
        items: <OrderItem>[
          item(
            id: 'o10-i1',
            productId: 'p-diabla',
            name: 'Camarones A LA Diabla',
            isCompleted: true,
          ),
        ],
      ),
      // Station 2 sample so switching stations works
      Order(
        id: 'order-11',
        displayNumber: '356800',
        stationId: 'station-2',
        createdAt: now.subtract(const Duration(minutes: 5)),
        type: OrderType.dineIn,
        status: OrderStatus.newOrder,
        tableNumber: '08',
        customerName: 'Casey Jones',
        items: <OrderItem>[
          item(id: 'o11-i1', productId: 'p-bisque', name: 'Lobster Bisque'),
          item(id: 'o11-i2', productId: 'p-caesar', name: 'Caesar Salad'),
        ],
      ),
    ];
  }
}
