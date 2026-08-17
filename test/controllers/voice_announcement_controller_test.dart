import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:order_master_kds/controllers/order_controller.dart';
import 'package:order_master_kds/controllers/voice_announcement_controller.dart';
import 'package:order_master_kds/core/utils/order_announcement.dart';
import 'package:order_master_kds/core/utils/order_title_number.dart';
import 'package:order_master_kds/models/kds_order_event.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/providers/kds_backend_providers.dart';
import 'package:order_master_kds/providers/order_title_number_providers.dart';
import 'package:order_master_kds/services/kds_tts_service.dart';

const String _station = 'station_grill';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('muted events do not speak', () async {
    final _RecordingKdsTts tts = _RecordingKdsTts();
    final ProviderContainer container = _container(
      tts: tts,
      enabled: false,
      stationId: _station,
    );
    addTearDown(container.dispose);
    container.listen(voiceAnnouncementProvider, (_, _) {});

    _emit(container, _event(kind: KdsOrderEventKind.newOrder));
    await pumpEventQueue();

    expect(tts.spoken, isEmpty);
  });

  test('station mismatch does not speak', () async {
    final _RecordingKdsTts tts = _RecordingKdsTts();
    final ProviderContainer container = _container(
      tts: tts,
      stationId: 'station-other',
    );
    addTearDown(container.dispose);
    container.listen(voiceAnnouncementProvider, (_, _) {});

    _emit(container, _event(kind: KdsOrderEventKind.newOrder));
    await pumpEventQueue();

    expect(tts.spoken, isEmpty);
  });

  test('matching station speaks announcementFor text', () async {
    final _RecordingKdsTts tts = _RecordingKdsTts();
    final ProviderContainer container = _container(tts: tts, stationId: _station);
    addTearDown(container.dispose);
    container.listen(voiceAnnouncementProvider, (_, _) {});

    final KdsOrderEvent event = _event(kind: KdsOrderEventKind.newOrder);
    _emit(container, event);
    await pumpEventQueue();

    expect(tts.spoken, <String>[announcementFor(event)]);
    expect(container.read(orderUpdatePulseUntilProvider), isEmpty);
  });

  test('matching station speaks kot number when KOT source is selected', () async {
    final _RecordingKdsTts tts = _RecordingKdsTts();
    final ProviderContainer container = _container(
      tts: tts,
      stationId: _station,
      titleNumberSource: OrderTitleNumberSource.kotNumber,
    );
    addTearDown(container.dispose);
    container.listen(voiceAnnouncementProvider, (_, _) {});

    final KdsOrderEvent event = _event(
      kind: KdsOrderEventKind.newOrder,
      kotNumber: '12',
    );
    _emit(container, event);
    await pumpEventQueue();

    expect(
      tts.spoken,
      <String>[
        announcementFor(
          event,
          titleNumberSource: OrderTitleNumberSource.kotNumber,
        ),
      ],
    );
  });

  test('four item events on one order speak one updated line', () async {
    final _RecordingKdsTts tts = _RecordingKdsTts();
    final ProviderContainer container = _container(tts: tts, stationId: _station);
    addTearDown(container.dispose);
    container.listen(voiceAnnouncementProvider, (_, _) {});

    _emit(container, _event(kind: KdsOrderEventKind.itemAdded, itemName: 'A'));
    _emit(container, _event(kind: KdsOrderEventKind.itemAdded, itemName: 'B'));
    _emit(container, _event(kind: KdsOrderEventKind.itemRemoved, itemName: 'C'));
    _emit(
      container,
      _event(
        kind: KdsOrderEventKind.itemQuantityChanged,
        oldQuantity: 1,
        newQuantity: 2,
      ),
    );
    await pumpEventQueue();

    expect(tts.spoken, <String>['Dine-in order 125, order updated.']);
    expect(
      container.read(orderUpdatePulseUntilProvider).containsKey('ord_125'),
      isTrue,
    );
  });

  test('type change plus items speaks only the type-change line', () async {
    final _RecordingKdsTts tts = _RecordingKdsTts();
    final ProviderContainer container = _container(tts: tts, stationId: _station);
    addTearDown(container.dispose);
    container.listen(voiceAnnouncementProvider, (_, _) {});

    _emit(container, _event(kind: KdsOrderEventKind.itemAdded));
    _emit(
      container,
      _event(
        kind: KdsOrderEventKind.orderTypeChanged,
        previousType: OrderType.dineIn,
        nextType: OrderType.takeOut,
        type: OrderType.takeOut,
      ),
    );
    _emit(container, _event(kind: KdsOrderEventKind.itemRemoved));
    await pumpEventQueue();

    expect(
      tts.spoken,
      <String>['Order 125 changed from Dine-in to Takeaway.'],
    );
  });

  test('four rapid events speak one summary, not four individuals', () async {
    final _RecordingKdsTts tts = _RecordingKdsTts();
    final ProviderContainer container = _container(tts: tts, stationId: _station);
    addTearDown(container.dispose);
    container.listen(voiceAnnouncementProvider, (_, _) {});

    for (int i = 1; i <= 4; i++) {
      _emit(
        container,
        _event(
          kind: KdsOrderEventKind.newOrder,
          orderId: 'ord_$i',
          displayNumber: '$i',
        ),
      );
    }
    await pumpEventQueue();

    expect(tts.spoken, <String>['4 orders updated.']);
  });

  test('type-change after three announcements speaks the type line', () async {
    final _RecordingKdsTts tts = _RecordingKdsTts();
    final ProviderContainer container = _container(tts: tts, stationId: _station);
    addTearDown(container.dispose);
    container.listen(voiceAnnouncementProvider, (_, _) {});

    for (int i = 1; i <= 3; i++) {
      _emit(
        container,
        _event(
          kind: KdsOrderEventKind.itemAdded,
          orderId: 'ord_$i',
          displayNumber: '$i',
        ),
      );
      await pumpEventQueue();
    }

    _emit(
      container,
      _event(
        kind: KdsOrderEventKind.orderTypeChanged,
        previousType: OrderType.dineIn,
        nextType: OrderType.takeOut,
        type: OrderType.takeOut,
      ),
    );
    await pumpEventQueue();

    expect(
      tts.spoken,
      contains('Order 125 changed from Dine-in to Takeaway.'),
    );
    expect(tts.spoken, isNot(contains(announcementOverflowLine)));
  });

  test('cancelled speaks after three other announcements', () async {
    final _RecordingKdsTts tts = _RecordingKdsTts();
    final ProviderContainer container = _container(tts: tts, stationId: _station);
    addTearDown(container.dispose);
    container.listen(voiceAnnouncementProvider, (_, _) {});

    for (int i = 1; i <= 3; i++) {
      _emit(
        container,
        _event(
          kind: KdsOrderEventKind.itemAdded,
          orderId: 'ord_$i',
          displayNumber: '$i',
        ),
      );
      await pumpEventQueue();
    }

    _emit(container, _event(kind: KdsOrderEventKind.cancelled));
    await pumpEventQueue();

    expect(tts.spoken, contains('Dine-in order 125, order cancelled.'));
  });

  test('four sequential same-order updates speak one updated line', () async {
    final _RecordingKdsTts tts = _RecordingKdsTts();
    final ProviderContainer container = _container(tts: tts, stationId: _station);
    addTearDown(container.dispose);
    container.listen(voiceAnnouncementProvider, (_, _) {});

    for (int i = 0; i < 4; i++) {
      _emit(
        container,
        _event(kind: KdsOrderEventKind.itemAdded, itemName: 'Item $i'),
      );
      await pumpEventQueue();
    }

    expect(tts.spoken, <String>['Dine-in order 125, order updated.']);
  });
}

ProviderContainer _container({
  required _RecordingKdsTts tts,
  bool enabled = true,
  required String stationId,
  int pulseSeconds = 30,
  OrderTitleNumberSource titleNumberSource =
      OrderTitleNumberSource.displayNumber,
}) {
  return ProviderContainer(
    overrides: [
      kdsTtsServiceProvider.overrideWith((Ref ref) => tts),
      announcementsEnabledProvider.overrideWith((Ref ref) => enabled),
      selectedStationProvider.overrideWith((Ref ref) => stationId),
      orderUpdatePulseSecondsProvider.overrideWith((Ref ref) => pulseSeconds),
      orderTitleNumberSourceProvider.overrideWith(
        (Ref ref) => titleNumberSource,
      ),
    ],
  );
}

void _emit(ProviderContainer container, KdsOrderEvent event) {
  container.read(orderEventsControllerProvider).add(event);
}

KdsOrderEvent _event({
  required KdsOrderEventKind kind,
  String orderId = 'ord_125',
  String displayNumber = '125',
  String? kotNumber,
  String? itemName,
  int? oldQuantity,
  int? newQuantity,
  OrderType type = OrderType.dineIn,
  OrderType? previousType,
  OrderType? nextType,
}) {
  return KdsOrderEvent(
    kind: kind,
    orderId: orderId,
    displayNumber: displayNumber,
    kotNumber: kotNumber,
    stationId: _station,
    type: type,
    itemName: itemName,
    oldQuantity: oldQuantity,
    newQuantity: newQuantity,
    previousType: previousType,
    nextType: nextType,
  );
}

/// Records speak/stop without a real engine. [stop] drops queued lines so a
/// burst collapse matches native queue flush.
class _RecordingKdsTts extends KdsTtsService {
  _RecordingKdsTts() : super(tts: _UnusedFlutterTts(), isIos: false);

  final List<String> spoken = <String>[];
  int stopCount = 0;
  int initCount = 0;

  @override
  Future<void> init() async {
    initCount += 1;
  }

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    spoken.clear();
  }
}

class _UnusedFlutterTts extends FlutterTts {}
