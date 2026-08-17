import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/core/utils/order_column_packer.dart';
import 'package:order_master_kds/core/utils/order_title_number.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/order_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

Order _order() {
  return Order(
    id: 'ord-1',
    displayNumber: '5',
    kotNumber: '12',
    stationId: 'station_grill',
    createdAt: DateTime.utc(2026, 8, 14, 12),
    type: OrderType.dineIn,
    status: OrderStatus.cooking,
    tableNumber: '3',
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

  testWidgets('card title uses display number by default', (
    WidgetTester tester,
  ) async {
    await _pumpCard(tester, OrderTitleNumberSource.displayNumber);
    expect(find.text('Order #5'), findsOneWidget);
    expect(find.text('Order #12'), findsNothing);
  });

  testWidgets('card title uses kot number when KOT source is selected', (
    WidgetTester tester,
  ) async {
    await _pumpCard(tester, OrderTitleNumberSource.kotNumber);
    expect(find.text('Order #12'), findsOneWidget);
    expect(find.text('Order #5'), findsNothing);
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  OrderTitleNumberSource source,
) async {
  final Order order = _order();
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
        orderTitleNumberSourceProvider.overrideWith((Ref ref) => source),
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
