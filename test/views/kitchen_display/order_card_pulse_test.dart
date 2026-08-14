import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/core/theme/app_colors.dart';
import 'package:order_master_kds/core/utils/order_column_packer.dart';
import 'package:order_master_kds/models/order_item_model.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/order_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

Order _order(String id, String displayNumber) {
  return Order(
    id: id,
    displayNumber: displayNumber,
    stationId: 'station_grill',
    createdAt: DateTime.utc(2026, 8, 14, 12),
    type: OrderType.dineIn,
    status: OrderStatus.cooking,
    tableNumber: '3',
    items: <OrderItem>[
      OrderItem(
        id: 'item-$id',
        productId: 'p-1',
        nameSnapshot: 'Burger',
        quantity: 1,
      ),
    ],
  );
}

CardSegment _segment(String orderId) {
  return CardSegment(
    orderId: orderId,
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

  testWidgets('updated order card pulses and a different order does not', (
    WidgetTester tester,
  ) async {
    final Order pulsing = _order('ord-pulse', '125');
    final Order other = _order('ord-other', '126');
    final DateTime until = DateTime.now().toUtc().add(const Duration(seconds: 30));

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
            if (id == pulsing.id) {
              return pulsing;
            }
            if (id == other.id) {
              return other;
            }
            return null;
          }),
          orderUpdatePulseUntilProvider.overrideWith(
            (Ref ref) => <String, DateTime>{pulsing.id: until},
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                SizedBox(
                  width: 280,
                  child: OrderCard(segment: _segment(pulsing.id)),
                ),
                SizedBox(
                  width: 280,
                  child: OrderCard(segment: _segment(other.id)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_isPulsing(tester, pulsing.id), isTrue);
    expect(_isPulsing(tester, other.id), isFalse);
  });
}

bool _isPulsing(WidgetTester tester, String orderId) {
  final DecoratedBox box = tester.widget(
    find.byKey(Key('order-update-pulse-$orderId')),
  );
  final BoxDecoration decoration = box.decoration as BoxDecoration;
  final Border border = decoration.border! as Border;
  return border.top.color != Colors.transparent &&
      border.top.color.a > 0 &&
      border.top.color.withValues(alpha: 1.0) ==
          AppColors.orderUpdatePulse.withValues(alpha: 1.0);
}
