import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';

class PinIndicator extends StatelessWidget {
  const PinIndicator({super.key, required this.filledCount});

  static const int pinLength = 4;

  final int filledCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(pinLength, (int index) {
        final bool isFilled = index < filledCount;

        return Padding(
          padding: EdgeInsets.only(
            right: index == pinLength - 1 ? 0 : AppSpacing.gutter,
          ),
          child: Container(
            width: AppSpacing.gutter,
            height: AppSpacing.gutter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled
                  ? AppColors.primary
                  : AppColors.surfaceContainerLow,
              border: Border.all(
                color: isFilled ? AppColors.primary : AppColors.outlineVariant,
                width: AppRadii.sm,
              ),
            ),
          ),
        );
      }),
    );
  }
}
