import 'dart:async';

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

/// Keypad cheat-sheet under the board.
///
/// Hidden until the first mapped physical key press, then auto-hides after
/// [KdsTiming.keypadLegendIdleTimeout] of inactivity.
class KeypadLegendBar extends ConsumerStatefulWidget {
  const KeypadLegendBar({super.key});

  @override
  ConsumerState<KeypadLegendBar> createState() => _KeypadLegendBarState();
}

class _KeypadLegendBarState extends ConsumerState<KeypadLegendBar> {
  Timer? _hideTimer;
  DateTime? _scheduledUntil;

  @override
  void dispose() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _scheduledUntil = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final KeypadState state = ref.watch(keypadProvider);
    final DateTime? until = state.legendVisibleUntil;

    final bool shouldShow = until != null && DateTime.now().isBefore(until);

    if (!shouldShow) {
      _hideTimer?.cancel();
      _hideTimer = null;
      _scheduledUntil = null;
      return const SizedBox.shrink(key: Key('keypad-legend-bar-hidden'));
    }

    // Reschedule only when the visibility target changes.
    if (_hideTimer == null || _scheduledUntil != until) {
      _hideTimer?.cancel();
      _hideTimer = null;
      _scheduledUntil = until;

      final Duration delay = until.difference(DateTime.now());
      _hideTimer = Timer(delay, () {
        if (!mounted) {
          return;
        }
        // Ignore stale timer callbacks if a newer physical key press
        // extended the legend.
        final DateTime? currentUntil =
            ref.read(keypadProvider).legendVisibleUntil;
        if (currentUntil == until) {
          ref.read(keypadProvider.notifier).clearLegendVisibleUntil();
        }
      });
    }

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
