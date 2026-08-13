class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  final String id;
  final String name;
  final int sortOrder;
}
