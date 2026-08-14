import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/urgency_settings_controller.dart';
import 'package:order_master_kds/core/constants/kds_layout.dart';
import 'package:order_master_kds/core/theme/app_theme.dart';
import 'package:order_master_kds/models/urgency_settings.dart';
import 'package:order_master_kds/providers/providers.dart';
import 'package:order_master_kds/services/urgency_settings_service.dart';
import 'package:order_master_kds/views/kitchen_display/kitchen_display_screen.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/order_board.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/product_sidebar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('product sidebar is visible by default in landscape', (
    WidgetTester tester,
  ) async {
    await _pumpKitchenDisplay(tester);

    expect(find.byType(ProductSidebar), findsOneWidget);
    expect(tester.getSize(find.byType(ProductSidebar)).width, KdsLayout.sidebarWidth);
  });

  testWidgets('hiding the list removes the sidebar and widens the board', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pumpKitchenDisplay(tester);

    final double widthWithSidebar = tester
        .widget<OrderBoard>(find.byType(OrderBoard))
        .boardWidth;

    container.read(productQuantityListVisibleProvider.notifier).state = false;
    await tester.pumpAndSettle();

    expect(find.byType(ProductSidebar), findsNothing);
    final double widthWithoutSidebar = tester
        .widget<OrderBoard>(find.byType(OrderBoard))
        .boardWidth;
    expect(
      widthWithoutSidebar,
      closeTo(widthWithSidebar + KdsLayout.sidebarWidth, 0.5),
    );
  });

  testWidgets('showing the list again restores the sidebar layout', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pumpKitchenDisplay(
      tester,
      visible: false,
    );

    expect(find.byType(ProductSidebar), findsNothing);

    container.read(productQuantityListVisibleProvider.notifier).state = true;
    await tester.pumpAndSettle();

    expect(find.byType(ProductSidebar), findsOneWidget);
  });
}

Future<ProviderContainer> _pumpKitchenDisplay(
  WidgetTester tester, {
  bool visible = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

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
      productQuantityListVisibleProvider.overrideWith((Ref ref) => visible),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: appLightTheme,
        home: const KitchenDisplayScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
