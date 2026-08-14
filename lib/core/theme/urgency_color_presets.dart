import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Preset header colors for order urgency.
///
/// These fill the status header band behind white [AppColors.onStatusHeader]
/// order # / time text. Only mid-to-deep saturated hues — no pale, pastel,
/// cream, or near-white swatches that would fail contrast.
abstract final class UrgencyColorPresets {
  static const List<Color> warningColorPresets = <Color>[
    AppColors.urgencyWarning, // 0xFFF59E0B — current default
    Color(0xFFD97706),
    Color(0xFFEA580C),
    Color(0xFFF97316),
    Color(0xFFCA8A04),
    Color(0xFFB45309),
    Color(0xFFC2410C),
    Color(0xFFA16207), // deep gold/mustard
    Color(0xFF92400E), // deep amber-brown
    Color(0xFF9A3412), // deep burnt orange
    Color(0xFF854D0E), // deep ochre
    Color(0xFF7C2D12), // very deep rust
  ];

  static const List<Color> criticalColorPresets = <Color>[
    AppColors.urgencyCritical, // 0xFFEF4444 — current default
    Color(0xFFDC2626),
    Color(0xFFB91C1C),
    Color(0xFFE11D48),
    Color(0xFFBE123C),
    Color(0xFFF43F5E),
    Color(0xFF9F1239),
    Color(0xFF7F1D1D), // deep red/maroon
    Color(0xFF991B1B), // deep red
    Color(0xFF881337), // deep rose
    Color(0xFF9D174D), // deep pink/berry
    Color(0xFFC2185B), // deep magenta-red
  ];
}
