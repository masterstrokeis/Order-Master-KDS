import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/keypad_controller.dart';
import '../../../core/constants/kds_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/keypad_legend.dart';
import '../../../models/keypad_state.dart';
import '../../../models/order_model.dart';
import '../../../providers/providers.dart';

/// Always-visible keypad cheat-sheet under the board.
class KeypadLegendBar extends ConsumerWidget {
  const KeypadLegendBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final KeypadState state = ref.watch(keypadProvider);
    final String? focusedId = state.focusedOrderId;
    final OrderStatus? focusedStatus = focusedId == null
        ? null
        : ref.watch(orderByIdProvider(focusedId))?.status;

    final List<KeypadLegendEntry> entries = keypadLegendFor(
      KeypadLegendContext(
        surface: _legendSurface(state.surface),
        focusedStatus: focusedStatus,
        hasDigits: state.digits.isNotEmpty,
      ),
    );

    return ColoredBox(
      key: const Key('keypad-legend-bar'),
      color: AppColors.chromeHeader,
      child: SizedBox(
        height: KdsLayout.legendBarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Row(
            children: [
              for (final KeypadLegendEntry entry in entries)
                Expanded(
                  child: Text(
                    '${entry.keyLabel}  ${entry.action}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelCaps.copyWith(
                      color: AppColors.chromeOnSurfaceMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

KeypadLegendSurface _legendSurface(KeypadSurface surface) {
  return switch (surface) {
    KeypadSurface.board => KeypadLegendSurface.board,
    KeypadSurface.sidebar => KeypadLegendSurface.sidebar,
    KeypadSurface.breakdownPanel => KeypadLegendSurface.breakdownPanel,
  };
}
