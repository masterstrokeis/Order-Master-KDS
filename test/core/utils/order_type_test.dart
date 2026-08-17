import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/core/utils/order_type_display.dart';
import 'package:order_master_kds/models/order_type.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/order_type_row.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/status_header_band.dart';

void main() {
  test('parse maps new wire values and old camelCase', () {
    expect(OrderType.parse('DINE-IN'), OrderType.dineIn);
    expect(OrderType.parse('TAKE AWAY'), OrderType.takeOut);
    expect(OrderType.parse('DELIVERY'), OrderType.delivery);
    expect(OrderType.parse('dineIn'), OrderType.dineIn);
    expect(OrderType.parse('takeOut'), OrderType.takeOut);
    expect(OrderType.parse('delivery'), OrderType.delivery);
  });

  test('unknown types keep the original string and compare by wire', () {
    final OrderType buffet = OrderType.parse('BUFFET');
    expect(buffet.kind, OrderTypeKind.other);
    expect(buffet.displayLabel, 'BUFFET');
    expect(buffet.serviceLabel(), 'BUFFET');
    expect(buffet, OrderType.parse('BUFFET'));
    expect(buffet, isNot(OrderType.parse('CATERING')));
    expect(orderTypeHeaderIcon(buffet), Icons.receipt_long_outlined);
  });

  test('dine-in service label uses table number', () {
    expect(
      OrderType.dineIn.serviceLabel(tableNumber: '05'),
      'Table - 05',
    );
    expect(OrderType.dineIn.serviceLabel(), 'Table - --');
    expect(OrderType.takeOut.displayLabel, 'Take Away');
    expect(OrderType.takeOut.serviceLabel(tableNumber: '05'), 'Take Away');
    expect(OrderType.delivery.serviceLabel(), 'Delivery');
  });

  testWidgets('header and type row show pretty known labels and raw unknown', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: const Scaffold(
          body: Column(
            children: [
              OrderTypeHeaderIndicator(orderType: OrderType.delivery),
              OrderTypeRow(type: OrderType.dineIn, tableNumber: '05'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Delivery'), findsOneWidget);
    expect(find.text('Table - 05'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: Scaffold(
          body: OrderTypeHeaderIndicator(orderType: OrderType.parse('BUFFET')),
        ),
      ),
    );
    expect(find.text('BUFFET'), findsOneWidget);
  });
}
