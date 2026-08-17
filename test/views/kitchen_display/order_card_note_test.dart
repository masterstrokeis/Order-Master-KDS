import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/core/utils/order_column_packer.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/order_card.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/order_note_band.dart';
import 'package:shared_preferences/shared_preferences.dart';

Order _order({String? note}) {
  return Order(
    id: 'ord-1',
    displayNumber: '5',
    stationId: 'station_grill',
    createdAt: DateTime.utc(2026, 8, 14, 12),
    type: OrderType.dineIn,
    status: OrderStatus.cooking,
    tableNumber: '3',
    note: note,
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

CardSegment _segment() {
  return const CardSegment(
    orderId: 'ord-1',
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('primary card shows order note', (WidgetTester tester) async {
    await _pumpCard(tester, _order(note: 'No spicy'));
    expect(find.byType(OrderNoteBand), findsOneWidget);
    expect(find.text('Note: No spicy'), findsOneWidget);
  });

  testWidgets('primary card hides empty or whitespace order note', (
    WidgetTester tester,
  ) async {
    await _pumpCard(tester, _order());
    expect(find.byType(OrderNoteBand), findsNothing);

    await _pumpCard(tester, _order(note: '   '));
    expect(find.byType(OrderNoteBand), findsNothing);
  });
}

Future<void> _pumpCard(WidgetTester tester, Order order) async {
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
            child: OrderCard(segment: _segment()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
