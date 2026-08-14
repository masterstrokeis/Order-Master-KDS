import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/constants/kds_timing.dart';
import '../core/utils/announcement_burst.dart';
import '../core/utils/order_announcement.dart';
import '../models/kds_order_event.dart';
import '../providers/kds_backend_providers.dart';
import '../services/announcement_preference_service.dart';
import '../services/kds_tts_service.dart';
import '../services/order_update_pulse_preference_service.dart';
import 'order_controller.dart';

final Provider<AnnouncementPreferenceService>
announcementPreferenceServiceProvider = Provider<AnnouncementPreferenceService>(
  (Ref ref) => AnnouncementPreferenceService(),
);

final Provider<OrderUpdatePulsePreferenceService>
orderUpdatePulsePreferenceServiceProvider =
    Provider<OrderUpdatePulsePreferenceService>(
      (Ref ref) => OrderUpdatePulsePreferenceService(),
    );

final Provider<KdsTtsService> kdsTtsServiceProvider = Provider<KdsTtsService>(
  (Ref ref) => KdsTtsService(),
);

/// Mute toggle. Default on so kitchens hear tickets without opening Settings.
/// Persistence is the Settings switch (step 5), same as [themeModeProvider].
final StateProvider<bool> announcementsEnabledProvider = StateProvider<bool>(
  (Ref ref) => true,
);

/// Seconds an updated card stays pulsing. Default from [KdsTiming].
final StateProvider<int> orderUpdatePulseSecondsProvider = StateProvider<int>(
  (Ref ref) => KdsTiming.orderUpdateHighlightDuration.inSeconds,
);

/// UTC expiry per order id. Cards blink while `now < until`.
final StateProvider<Map<String, DateTime>> orderUpdatePulseUntilProvider =
    StateProvider<Map<String, DateTime>>(
      (Ref ref) => const <String, DateTime>{},
    );

/// Owns the order-events listen, station/mute filters, and burst/cap policy.
///
/// State is [void]: nothing in the UI reads announcer status. Keep-alive is
/// [ref.watch] from [OrderMasterApp], not this value.
class VoiceAnnouncementController extends Notifier<void> {
  List<TimedAnnouncementEvent> _recent = <TimedAnnouncementEvent>[];
  List<String> _pending = <String>[];
  final List<KdsOrderEvent> _snapshotBuffer = <KdsOrderEvent>[];
  bool _flushScheduled = false;
  bool _didInitTts = false;

  @override
  void build() {
    if (!_didInitTts) {
      _didInitTts = true;
      unawaited(ref.read(kdsTtsServiceProvider).init());
    }

    ref.listen<bool>(announcementsEnabledProvider, (
      bool? previous,
      bool next,
    ) {
      if (previous == true && next == false) {
        _pending = <String>[];
        _recent = <TimedAnnouncementEvent>[];
        _snapshotBuffer.clear();
        _flushScheduled = false;
        unawaited(ref.read(kdsTtsServiceProvider).stop());
      }
    });

    ref.listen<AsyncValue<KdsOrderEvent>>(orderEventsProvider, (
      AsyncValue<KdsOrderEvent>? previous,
      AsyncValue<KdsOrderEvent> next,
    ) {
      next.whenData(_onEvent);
    });
  }

  void _onEvent(KdsOrderEvent event) {
    if (!ref.read(announcementsEnabledProvider)) {
      return;
    }
    final String? stationId = ref.read(selectedStationProvider);
    if (stationId == null || event.stationId != stationId) {
      return;
    }

    // One replace can emit N low-level diffs synchronously (sync broadcast).
    // Flush on the next microtask so the kitchen hears one line per order.
    _snapshotBuffer.add(event);
    if (_flushScheduled) {
      return;
    }
    _flushScheduled = true;
    scheduleMicrotask(_flush);
  }

  void _flush() {
    _flushScheduled = false;
    final List<KdsOrderEvent> batch = List<KdsOrderEvent>.of(_snapshotBuffer);
    _snapshotBuffer.clear();
    if (batch.isEmpty || !ref.read(announcementsEnabledProvider)) {
      return;
    }

    final DateTime now = DateTime.now().toUtc();
    final KdsTtsService tts = ref.read(kdsTtsServiceProvider);
    for (final KdsOrderEvent event in coalesceAnnouncements(batch)) {
      final AnnouncementBurstResult result = applyAnnouncementBurst(
        recent: _recent,
        incoming: TimedAnnouncementEvent(event: event, at: now),
        now: now,
        pending: _pending,
      );
      _recent = result.recent;
      _pending = result.pending;

      if ((result.recent.isEmpty || result.interrupt) &&
          result.enqueued.isNotEmpty) {
        unawaited(tts.stop());
      }
      for (final String line in result.enqueued) {
        unawaited(tts.speak(line));
      }

      if (shouldPulseForEvent(event)) {
        _pulseOrder(event.orderId, now);
      }
    }
  }

  void _pulseOrder(String orderId, DateTime now) {
    final int seconds = ref.read(orderUpdatePulseSecondsProvider);
    final DateTime until = now.add(Duration(seconds: seconds));
    final Map<String, DateTime> next = Map<String, DateTime>.from(
      ref.read(orderUpdatePulseUntilProvider),
    );
    next[orderId] = until;
    ref.read(orderUpdatePulseUntilProvider.notifier).state = next;
  }
}

final NotifierProvider<VoiceAnnouncementController, void>
voiceAnnouncementProvider =
    NotifierProvider<VoiceAnnouncementController, void>(
      VoiceAnnouncementController.new,
    );
