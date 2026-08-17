import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/theme/app_colors.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/order_action_footer.dart';

void main() {
  testWidgets('stale leftover footer shows Clear for every status', (
    WidgetTester tester,
  ) async {
    for (final OrderStatus status in OrderStatus.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: appLightTheme,
          home: Scaffold(
            body: OrderActionFooter(
              status: status,
              accentColor: AppColors.statusCooking,
              staleLeftover: true,
              onStart: () {},
              onComplete: () {},
              onRollback: () {},
              onClear: () {},
            ),
          ),
        ),
      );
      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('Complete'), findsNothing);
      expect(find.text('Start'), findsNothing);
      expect(find.text('Roll back'), findsNothing);
    }
  });

  testWidgets('live cooking footer still shows Complete', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: Scaffold(
          body: OrderActionFooter(
            status: OrderStatus.cooking,
            accentColor: AppColors.statusCooking,
            onStart: () {},
            onComplete: () {},
            onRollback: () {},
            onClear: () {},
          ),
        ),
      ),
    );
    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);
  });
}
