import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/keypad_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/keypad_state.dart';

/// Floating type-ahead / flash pill. Hidden when idle.
class KeypadTypeAheadIndicator extends ConsumerWidget {
  const KeypadTypeAheadIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? label = ref.watch(keypadProvider.select(_labelFor));
    if (label == null) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.gutter),
          child: Material(
            key: const Key('keypad-type-ahead'),
            color: AppColors.chromeHeader,
            borderRadius: BorderRadius.circular(AppRadii.full),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
                vertical: AppSpacing.unit,
              ),
              child: Text(
                label,
                style: AppTextStyles.labelCaps.copyWith(
                  color: AppColors.chromeOnSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _labelFor(KeypadState state) {
  final String? flash = state.flash;
  if (flash != null && flash.isNotEmpty) {
    return flash;
  }
  if (state.digits.isEmpty) {
    return null;
  }
  final String body = '${state.digits}_';
  return switch (state.surface) {
    KeypadSurface.board =>
      state.focusedOrderId == null ? 'Order $body' : 'Item $body',
    KeypadSurface.sidebar => 'Item group $body',
    KeypadSurface.breakdownPanel => 'Line $body',
  };
}
