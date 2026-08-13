import 'order_model.dart';

class KdsApiError implements Exception {
  const KdsApiError({
    required this.code,
    required this.message,
    this.details = const <String, dynamic>{},
    this.currentVersion,
    this.order,
    this.statusCode,
  });

  factory KdsApiError.fromJson(
    Map<String, dynamic> json, {
    int? statusCode,
  }) {
    final Map<String, dynamic> error =
        json['error'] as Map<String, dynamic>? ?? json;
    final Object? orderJson = json['order'];
    return KdsApiError(
      statusCode: statusCode,
      code: error['code'] as String? ?? 'UNKNOWN',
      message: error['message'] as String? ?? 'Unknown error',
      details: error['details'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      currentVersion: error['currentVersion'] as int?,
      order: orderJson is Map<String, dynamic>
          ? Order.fromJson(orderJson)
          : null,
    );
  }

  final int? statusCode;
  final String code;
  final String message;
  final Map<String, dynamic> details;
  final int? currentVersion;
  final Order? order;

  bool get isVersionConflict => code == 'VERSION_CONFLICT';

  bool get isInvalidTransition => code == 'INVALID_TRANSITION';

  @override
  String toString() => 'KdsApiError($code): $message';
}
