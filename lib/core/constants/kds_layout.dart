abstract final class KdsLayout {
  static const double sidebarWidth = 224;
  static const double minimumColumnWidth = 280;
  static const int minColumns = 1;
  static const int maxColumns = 5;
  static const int preferredTabletColumns = 2;
  static const int preferredDesktopMinColumns = 4;

  /// Header band: 12px pad × 2 + order# (~24) + gap + time (~16) ≈ 64.
  static const double headerBandHeight = 64;

  /// Order-type row: 12px pad × 2 + ~20 text ≈ 48.
  static const double orderTypeRowHeight = 48;

  static const double continuedLabelHeight = 32;

  /// Footer button (48) + spacer above it (8).
  static const double footerHeight = 56;

  /// Card body `EdgeInsets.all(12)` top + bottom.
  static const double cardBodyVerticalPadding = 24;

  static const double cardBorderWidth = 1;
  static const double cardGap = 16;
  static const double itemVerticalGap = 16;
  static const double cardBodyHorizontalPadding = 12;
  static const double qtyColumnWidth = 20;
  static const double itemTextGap = 12;

  /// Conservative (slightly narrow) so wrap estimates prefer more lines.
  static const double averageCharWidth = 6.5;

  /// Matches `AppTextStyles.bodyMd` (16px / height 1.5 → 24).
  static const double nameLineHeight = 24;

  /// 12px secondary text ≈ 16–18; pad top 4 included below.
  static const double modifierLineHeight = 18;
  static const double noteLineHeight = 18;
  static const double secondaryTextTopPadding = 4;

  /// Prefer early split over clipping; covers font/platform drift.
  static const double heightSafetyAllowance = 28;
}
