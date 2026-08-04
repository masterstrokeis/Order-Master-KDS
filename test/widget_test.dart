import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/app.dart';
import 'package:order_master_kds/core/theme/app_colors.dart';
import 'package:order_master_kds/providers/providers.dart';

void main() {
  testWidgets('defaults to the light KDS theme', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: OrderMasterApp()));

    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    final BuildContext scaffoldContext = tester.element(find.byType(Scaffold));

    expect(app.themeMode, ThemeMode.light);
    expect(
      Theme.of(scaffoldContext).scaffoldBackgroundColor,
      AppColors.lightBackground,
    );
    expect(find.text('La Botica'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('can open kitchen display with overridden theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeModeProvider.overrideWith((Ref ref) => ThemeMode.dark),
        ],
        child: const OrderMasterApp(),
      ),
    );

    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
