class Station {
  const Station({
    required this.id,
    required this.name,
    this.displayOrder = 0,
  });

  final String id;
  final String name;
  final int displayOrder;
}
