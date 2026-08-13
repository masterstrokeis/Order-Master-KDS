class Product {
  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    this.stationIds = const <String>[],
    this.isActive = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawStationIds =
        json['stationIds'] as List<dynamic>? ?? const <dynamic>[];
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      categoryId: json['categoryId'] as String,
      stationIds: rawStationIds.map((dynamic e) => e as String).toList(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String categoryId;
  final List<String> stationIds;
  final bool isActive;
}
