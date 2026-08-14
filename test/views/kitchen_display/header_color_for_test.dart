import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/theme/app_colors.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/views/kitchen_display/widgets/order_card.dart';

void main() {
  const Brightness brightness = Brightness.light;

  test('warning urgency returns injected warningColor, not AppColors default', () {
    const Color customWarning = Color(0xFF123456);

    final Color result = headerColorFor(
      status: OrderStatus.cooking,
      urgency: OrderUrgency.warning,
      brightness: brightness,
      warningColor: customWarning,
    );

    expect(result, customWarning);
    expect(result, isNot(AppColors.urgencyWarning));
  });

  test('critical urgency returns injected criticalColor, not AppColors default', () {
    const Color customCritical = Color(0xFF654321);

    final Color result = headerColorFor(
      status: OrderStatus.cooking,
      urgency: OrderUrgency.critical,
      brightness: brightness,
      criticalColor: customCritical,
    );

    expect(result, customCritical);
    expect(result, isNot(AppColors.urgencyCritical));
  });

  test('cancelled status ignores urgency colors', () {
    const Color customCritical = Color(0xFF654321);

    final Color result = headerColorFor(
      status: OrderStatus.cancelled,
      urgency: OrderUrgency.critical,
      brightness: brightness,
      criticalColor: customCritical,
    );

    expect(result, AppColors.statusCancelled);
  });

  test('default args still use AppColors urgency tokens', () {
    expect(
      headerColorFor(
        status: OrderStatus.cooking,
        urgency: OrderUrgency.warning,
        brightness: brightness,
      ),
      AppColors.urgencyWarning,
    );
    expect(
      headerColorFor(
        status: OrderStatus.cooking,
        urgency: OrderUrgency.critical,
        brightness: brightness,
      ),
      AppColors.urgencyCritical,
    );
  });
}
