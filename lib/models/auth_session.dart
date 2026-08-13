import 'restaurant_model.dart';
import 'staff_model.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.staff,
    required this.restaurant,
    required this.outlet,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      staff: Staff.fromJson(json['staff'] as Map<String, dynamic>),
      restaurant: Restaurant.fromJson(
        json['restaurant'] as Map<String, dynamic>,
      ),
      outlet: Outlet.fromJson(json['outlet'] as Map<String, dynamic>),
    );
  }

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final Staff staff;
  final Restaurant restaurant;
  final Outlet outlet;

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    Staff? staff,
    Restaurant? restaurant,
    Outlet? outlet,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      staff: staff ?? this.staff,
      restaurant: restaurant ?? this.restaurant,
      outlet: outlet ?? this.outlet,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'staff': <String, dynamic>{
        'id': staff.id,
        'name': staff.name,
        'initials': staff.initials,
        'roles': staff.roles,
      },
      'restaurant': <String, dynamic>{
        'id': restaurant.id,
        'name': restaurant.name,
      },
      'outlet': <String, dynamic>{
        'id': outlet.id,
        'name': outlet.name,
      },
    };
  }

  bool get isAccessTokenExpired {
    return DateTime.now().toUtc().isAfter(expiresAt.toUtc());
  }
}
