class Staff {
  const Staff({
    required this.id,
    required this.name,
    required this.initials,
    this.roles = const <String>[],
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawRoles =
        json['roles'] as List<dynamic>? ?? const <dynamic>[];
    return Staff(
      id: json['id'] as String,
      name: json['name'] as String,
      initials: json['initials'] as String,
      roles: rawRoles.map((dynamic e) => e as String).toList(),
    );
  }

  final String id;
  final String name;
  final String initials;
  final List<String> roles;
}
