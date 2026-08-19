import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/core/constants/kds_layout.dart';
import 'package:order_master_kds/core/theme/app_colors.dart';
import 'package:order_master_kds/core/utils/order_column_packer.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/order_card.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/order_elapsed_label.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/status_header_band.dart';
import 'package:shared_preferences/shared_preferences.dart';

Order _baseOrder({
  required OrderStatus status,
  DateTime? createdAt,
  DateTime? completedAt,
  DateTime? cancelledAt,
}) {
  final DateTime created = createdAt ?? DateTime(2026, 8, 14, 11, 52);
  return Order(
    id: 'ord-elapsed',
    displayNumber: '42',
    stationId: 'station_grill',
    createdAt: created,
    type: OrderType.dineIn,
    status: status,
    tableNumber: '3',
    completedAt: completedAt,
    cancelledAt: cancelledAt,
    items: <OrderItem>[
      OrderItem(
        id: 'item-1',
        productId: 'p-1',
        nameSnapshot: 'Burger',
        quantity: 1,
      ),
    ],
  );
}

CardSegment _primarySegment() {
  return const CardSegment(
    orderId: 'ord-elapsed',
    segmentIndex: 0,
    itemStartIndex: 0,
    itemEndIndex: 1,
    isPrimary: true,
    isFinal: true,
    showIncomingContinued: false,
    showOutgoingContinued: false,
    estimatedHeight: 200,
  );
}

CardSegment _continuationSegment() {
  return const CardSegment(
    orderId: 'ord-elapsed',
    segmentIndex: 1,
    itemStartIndex: 1,
    itemEndIndex: 2,
    isPrimary: false,
    isFinal: true,
    showIncomingContinued: true,
    showOutgoingContinued: false,
    estimatedHeight: 120,
  );
}

Future<void> _pumpHeader(
  WidgetTester tester, {
  required DateTime createdAt,
  DateTime? elapsedFrozenAt,
  required DateTime Function() nowBuilder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
      home: Scaffold(
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 280,
              child: StatusHeaderBand(
                orderId: 'ord-elapsed',
                displayNumber: '42',
                createdAt: createdAt,
                orderType: OrderType.dineIn,
                status: OrderStatus.cooking,
                headerColor: AppColors.statusCooking,
                elapsedFrozenAt: elapsedFrozenAt,
                elapsedNowBuilder: nowBuilder,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpOrderCard(
  WidgetTester tester, {
  required Order order,
  required CardSegment segment,
}) async {
  await tester.pumpWidget(
    ProviderScope(
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
        orderByIdProvider.overrideWith((Ref ref, String id) {
          return id == order.id ? order : null;
        }),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: OrderCard(segment: segment),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _BuildCountingParent extends StatefulWidget {
  const _BuildCountingParent({
    super.key,
    required this.createdAt,
    required this.elapsedFrozenAt,
    required this.nowBuilder,
  });

  final DateTime createdAt;
  final DateTime? elapsedFrozenAt;
  final DateTime Function() nowBuilder;

  @override
  State<_BuildCountingParent> createState() => _BuildCountingParentState();
}

class _BuildCountingParentState extends State<_BuildCountingParent> {
  int buildCount = 0;

  @override
  Widget build(BuildContext context) {
    buildCount++;
    return StatusHeaderBand(
      orderId: 'ord-elapsed',
      displayNumber: '42',
      createdAt: widget.createdAt,
      orderType: OrderType.dineIn,
      status: OrderStatus.cooking,
      headerColor: AppColors.statusCooking,
      elapsedFrozenAt: widget.elapsedFrozenAt,
      elapsedNowBuilder: widget.nowBuilder,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('freeze on terminal orders', () {
    testWidgets('completed label stays frozen with no timer', (
      WidgetTester tester,
    ) async {
      final DateTime createdAt = DateTime(2026, 8, 14, 11, 52);
      final DateTime completedAt = createdAt.add(const Duration(minutes: 15));
      DateTime now = completedAt;

      await _pumpHeader(
        tester,
        createdAt: createdAt,
        elapsedFrozenAt: completedAt,
        nowBuilder: () => now,
      );

      expect(find.text('15m'), findsOneWidget);

      now = now.add(const Duration(minutes: 5));
      await tester.pumpAndSettle();

      expect(find.text('15m'), findsOneWidget);
    });

    testWidgets('cancelled label stays frozen with no timer', (
      WidgetTester tester,
    ) async {
      final DateTime createdAt = DateTime(2026, 8, 14, 11, 52);
      final DateTime cancelledAt = createdAt.add(const Duration(minutes: 20));
      DateTime now = cancelledAt;

      await _pumpHeader(
        tester,
        createdAt: createdAt,
        elapsedFrozenAt: cancelledAt,
        nowBuilder: () => now,
      );

      expect(find.text('20m'), findsOneWidget);

      now = now.add(const Duration(minutes: 5));
      await tester.pumpAndSettle();

      expect(find.text('20m'), findsOneWidget);
    });
  });

  testWidgets('ticks across a minute boundary aligned to wall clock', (
    WidgetTester tester,
  ) async {
    final DateTime createdAt = DateTime(2026, 8, 14, 11, 52);
    DateTime now = DateTime(2026, 8, 14, 12, 0, 30);

    await _pumpHeader(
      tester,
      createdAt: createdAt,
      nowBuilder: () => now,
    );

    expect(find.text('8m'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 29999));
    expect(find.text('8m'), findsOneWidget);

    now = DateTime(2026, 8, 14, 12, 1);
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('9m'), findsOneWidget);
  });

  testWidgets('label tick does not rebuild StatusHeaderBand parent', (
    WidgetTester tester,
  ) async {
    final DateTime createdAt = DateTime(2026, 8, 14, 11, 52);
    DateTime now = DateTime(2026, 8, 14, 12, 0, 30);
    final GlobalKey<_BuildCountingParentState> parentKey =
        GlobalKey<_BuildCountingParentState>();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          textTheme: const TextTheme(
            bodyMedium: TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
        home: Scaffold(
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 280,
                child: _BuildCountingParent(
                  key: parentKey,
                  createdAt: createdAt,
                  elapsedFrozenAt: null,
                  nowBuilder: () => now,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final StatusHeaderBand before =
        tester.widget<StatusHeaderBand>(find.byType(StatusHeaderBand));
    expect(parentKey.currentState!.buildCount, 1);
    expect(find.text('8m'), findsOneWidget);

    now = DateTime(2026, 8, 14, 12, 1);
    await tester.pump(const Duration(seconds: 30));

    final StatusHeaderBand after =
        tester.widget<StatusHeaderBand>(find.byType(StatusHeaderBand));

    expect(find.text('9m'), findsOneWidget);
    expect(parentKey.currentState!.buildCount, 1);
    expect(identical(before, after), isTrue);
  });

  testWidgets('header height unchanged between short and long labels', (
    WidgetTester tester,
  ) async {
    final DateTime createdAt = DateTime(2026, 8, 14, 12);

    await _pumpHeader(
      tester,
      createdAt: createdAt,
      elapsedFrozenAt: createdAt.add(const Duration(minutes: 8)),
      nowBuilder: () => DateTime(2026, 8, 14, 13),
    );

    final double shortHeight = tester.getSize(
      find.byType(StatusHeaderBand),
    ).height;

    await _pumpHeader(
      tester,
      createdAt: createdAt,
      elapsedFrozenAt: createdAt.add(const Duration(minutes: 1439)),
      nowBuilder: () => DateTime(2026, 8, 15, 11, 59),
    );

    final double longHeight = tester.getSize(
      find.byType(StatusHeaderBand),
    ).height;

    expect(shortHeight, longHeight);
    expect(shortHeight, KdsLayout.headerBandHeight);
  });

  group('OrderCard structure', () {
    testWidgets('primary segment renders one elapsed label', (
      WidgetTester tester,
    ) async {
      final Order order = _baseOrder(status: OrderStatus.cooking);

      await _pumpOrderCard(
        tester,
        order: order,
        segment: _primarySegment(),
      );

      expect(find.byType(OrderElapsedLabel), findsOneWidget);
    });

    testWidgets('continuation segment renders no elapsed label', (
      WidgetTester tester,
    ) async {
      final Order order = _baseOrder(status: OrderStatus.cooking).copyWith(
        items: <OrderItem>[
          OrderItem(
            id: 'item-1',
            productId: 'p-1',
            nameSnapshot: 'Burger',
            quantity: 1,
          ),
          OrderItem(
            id: 'item-2',
            productId: 'p-2',
            nameSnapshot: 'Fries',
            quantity: 1,
          ),
        ],
      );

      await _pumpOrderCard(
        tester,
        order: order,
        segment: _continuationSegment(),
      );

      expect(find.byType(OrderElapsedLabel), findsNothing);
    });
  });
}
