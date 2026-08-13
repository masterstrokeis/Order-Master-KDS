import 'order_model.dart';

class SyncEvent {
  const SyncEvent({
    required this.eventId,
    required this.type,
    required this.occurredAt,
    required this.stationId,
    required this.order,
    this.cursor,
  });

  factory SyncEvent.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> payload =
        json['payload'] as Map<String, dynamic>;
    return SyncEvent(
      eventId: json['eventId'] as String,
      type: json['type'] as String,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      stationId: json['stationId'] as String,
      cursor: json['cursor'] as String?,
      order: Order.fromJson(payload['order'] as Map<String, dynamic>),
    );
  }

  final String eventId;
  final String type;
  final DateTime occurredAt;
  final String stationId;
  final String? cursor;
  final Order order;
}

class SyncResult {
  const SyncResult({
    required this.serverTime,
    required this.events,
    required this.nextCursor,
    required this.requiresFullReload,
  });

  factory SyncResult.fromJson(Map<String, dynamic> json) {
    return SyncResult(
      serverTime: DateTime.parse(json['serverTime'] as String),
      events: (json['events'] as List<dynamic>)
          .map((dynamic e) => SyncEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
      requiresFullReload: json['requiresFullReload'] as bool? ?? false,
    );
  }

  final DateTime serverTime;
  final List<SyncEvent> events;
  final String? nextCursor;
  final bool requiresFullReload;
}
