import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:order_master_kds/controllers/order_controller.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/kds_tts_service.dart';
import 'package:order_master_kds/services/kds_websocket_service.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/kitchen_display/kitchen_display_screen.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/shift_opened_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shift.closed shows toast and speaks', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpKitchenDisplay(tester);

    harness.socket.onShiftEvent!(
      ShiftEventKind.closed,
      'Business day has been closed',
    );
    await tester.pump();

    expect(find.text('Business day has been closed'), findsOneWidget);
    expect(harness.tts.spoken, <String>['Business day has been closed']);
  });

  testWidgets('shift.closed still toasts when announcements are muted', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpKitchenDisplay(
      tester,
      announcementsEnabled: false,
    );

    harness.socket.onShiftEvent!(
      ShiftEventKind.closed,
      'Business day has been closed',
    );
    await tester.pump();

    expect(find.text('Business day has been closed'), findsOneWidget);
    expect(harness.tts.spoken, isEmpty);
  });

  testWidgets('shift.opened with leftovers shows dialog; Clear empties board', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpKitchenDisplay(tester);
    expect(
      harness.container.read(orderControllerProvider).requireValue,
      isNotEmpty,
    );

    harness.socket.onShiftEvent!(
      ShiftEventKind.opened,
      'New business day has started',
    );
    await tester.pumpAndSettle();

    expect(find.byType(ShiftOpenedDialog), findsOneWidget);
    expect(find.text('New business day has started'), findsOneWidget);
    expect(find.byKey(const Key('shift-opened-clear')), findsOneWidget);
    expect(find.byKey(const Key('shift-opened-cancel')), findsOneWidget);
    expect(find.byKey(const Key('shift-opened-close')), findsOneWidget);
    expect(harness.tts.spoken, <String>['New business day has started']);

    await tester.tap(find.byKey(const Key('shift-opened-clear')));
    await tester.pumpAndSettle();

    expect(find.byType(ShiftOpenedDialog), findsNothing);
    expect(
      harness.container.read(orderControllerProvider).requireValue,
      isEmpty,
    );
    expect(harness.container.read(ordersForCurrentViewProvider), isEmpty);
  });

  testWidgets('shift.opened Cancel leaves orders unchanged', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpKitchenDisplay(tester);
    final int before = harness.container
        .read(orderControllerProvider)
        .requireValue
        .length;

    harness.socket.onShiftEvent!(
      ShiftEventKind.opened,
      'New business day has started',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shift-opened-cancel')));
    await tester.pumpAndSettle();

    expect(find.byType(ShiftOpenedDialog), findsNothing);
    expect(
      harness.container.read(orderControllerProvider).requireValue.length,
      before,
    );
  });

  testWidgets('shift.opened close icon leaves orders unchanged', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpKitchenDisplay(tester);
    final int before = harness.container
        .read(orderControllerProvider)
        .requireValue
        .length;

    harness.socket.onShiftEvent!(
      ShiftEventKind.opened,
      'New business day has started',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shift-opened-close')));
    await tester.pumpAndSettle();

    expect(find.byType(ShiftOpenedDialog), findsNothing);
    expect(
      harness.container.read(orderControllerProvider).requireValue.length,
      before,
    );
  });

  testWidgets('empty-board shift.opened auto-dismisses when first order arrives',
      (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpKitchenDisplay(tester);
    harness.container.read(orderControllerProvider.notifier).clearStationOrders();
    await tester.pumpAndSettle();

    harness.socket.onShiftEvent!(
      ShiftEventKind.opened,
      'New business day has started',
    );
    await tester.pumpAndSettle();
    expect(find.byType(ShiftOpenedDialog), findsOneWidget);

    harness.container.read(orderControllerProvider.notifier).replaceOrder(
      _incomingOrder(),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ShiftOpenedDialog), findsNothing);
    expect(
      harness.container.read(orderControllerProvider).requireValue.map(
        (Order o) => o.id,
      ),
      contains('ord_new_day:station-1'),
    );
  });

  testWidgets(
    'Cancel tears down auto-dismiss so a later order does not pop a new dialog',
    (WidgetTester tester) async {
      final _Harness harness = await _pumpKitchenDisplay(tester);
      harness.container
          .read(orderControllerProvider.notifier)
          .clearStationOrders();
      await tester.pumpAndSettle();

      harness.socket.onShiftEvent!(
        ShiftEventKind.opened,
        'New business day has started',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shift-opened-cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(ShiftOpenedDialog), findsNothing);

      harness.container.read(orderControllerProvider.notifier).clearStationOrders();
      await tester.pumpAndSettle();

      harness.socket.onShiftEvent!(
        ShiftEventKind.opened,
        'New business day has started',
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShiftOpenedDialog), findsOneWidget);

      harness.container.read(orderControllerProvider.notifier).replaceOrder(
        _incomingOrder(),
      );
      await tester.pump();

      // The first listen must already be closed; only the current empty-path
      // dialog auto-dismisses (once). A double-pop would throw.
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.byType(ShiftOpenedDialog), findsNothing);
    },
  );

  testWidgets(
    'incoming order is applied while the shift.opened dialog is still open',
    (WidgetTester tester) async {
      final _Harness harness = await _pumpKitchenDisplay(tester);

      harness.socket.onShiftEvent!(
        ShiftEventKind.opened,
        'New business day has started',
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShiftOpenedDialog), findsOneWidget);

      harness.container.read(orderControllerProvider.notifier).replaceOrder(
        _incomingOrder(),
      );
      await tester.pump();

      expect(find.byType(ShiftOpenedDialog), findsOneWidget);
      expect(
        harness.container.read(orderControllerProvider).requireValue.map(
          (Order o) => o.id,
        ),
        contains('ord_new_day:station-1'),
      );
    },
  );

  testWidgets(
    'after day-begin Cancel leftover cards show Clear and a new order does not',
    (WidgetTester tester) async {
      final _Harness harness = await _pumpKitchenDisplay(tester);
      final OrderController orders = harness.container.read(
        orderControllerProvider.notifier,
      );
      final String leftoverId = harness.container
          .read(orderControllerProvider)
          .requireValue
          .firstWhere((Order o) => o.status == OrderStatus.cooking)
          .id;

      harness.socket.onShiftEvent!(
        ShiftEventKind.opened,
        'New business day has started',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shift-opened-cancel')));
      await tester.pumpAndSettle();

      expect(orders.isStaleLeftover(leftoverId), isTrue);
      expect(find.text('Complete'), findsNothing);
      expect(find.text('Start'), findsNothing);
      expect(find.text('Clear'), findsWidgets);

      orders.replaceOrder(_incomingOrder());
      await tester.pumpAndSettle();

      expect(orders.isStaleLeftover(_incomingOrder().id), isFalse);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Clear'), findsWidgets);

      final int before = harness.container
          .read(orderControllerProvider)
          .requireValue
          .length;
      await tester.tap(find.text('Clear').first);
      await tester.pumpAndSettle();

      expect(
        harness.container.read(orderControllerProvider).requireValue.length,
        before - 1,
      );
    },
  );
}

class _Harness {
  const _Harness({
    required this.container,
    required this.tts,
    required this.socket,
  });

  final ProviderContainer container;
  final _RecordingKdsTts tts;
  final KdsWebSocketService socket;
}

Order _incomingOrder() {
  return Order(
    id: 'ord_new_day:station-1',
    displayNumber: 'N1',
    stationId: 'station-1',
    createdAt: DateTime.utc(2026, 8, 16, 11),
    type: OrderType.dineIn,
    status: OrderStatus.newOrder,
    items: <OrderItem>[
      OrderItem(
        id: 'item_new:station-1',
        productId: 'p-salmon-grill',
        nameSnapshot: 'Salmon Grill',
        quantity: 1,
      ),
    ],
  );
}

Future<_Harness> _pumpKitchenDisplay(
  WidgetTester tester, {
  bool announcementsEnabled = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  final _RecordingKdsTts tts = _RecordingKdsTts();
  final KdsWebSocketService socket = KdsWebSocketService(useMockBackend: true);
  final ProviderContainer container = ProviderContainer(
    overrides: [
      urgencySettingsServiceProvider.overrideWith(
        (Ref ref) => UrgencySettingsService(),
      ),
      urgencySettingsProvider.overrideWith(
        () => UrgencySettingsController(UrgencySettings.defaults),
      ),
      kdsClockProvider.overrideWith(
        (Ref ref) => Stream<DateTime>.value(DateTime.utc(2026, 8, 14, 12)),
      ),
      announcementsEnabledProvider.overrideWith(
        (Ref ref) => announcementsEnabled,
      ),
      kdsTtsServiceProvider.overrideWith((Ref ref) => tts),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: appLightTheme,
        home: KitchenDisplayScreen(socket: socket),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(container: container, tts: tts, socket: socket);
}

class _RecordingKdsTts extends KdsTtsService {
  _RecordingKdsTts() : super(tts: _UnusedFlutterTts(), isIos: false);

  final List<String> spoken = <String>[];

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }
}

class _UnusedFlutterTts extends FlutterTts {}
