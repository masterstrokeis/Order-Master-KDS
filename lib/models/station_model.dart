class Station {
  const Station({
    required this.id,
    required this.name,
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'] as String,
      name: json['name'] as String,
      displayOrder: json['displayOrder'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final int displayOrder;
  final bool isActive;
}
