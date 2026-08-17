abstract final class KdsTiming {
  static const Duration warningThreshold = Duration(minutes: 1);
  static const Duration criticalThreshold = Duration(minutes: 2);
  static const Duration clockTickInterval = Duration(seconds: 3);
  static const Duration orderUpdateHighlightDuration = Duration(seconds: 30);
  static const Duration cancelledCookingDisplayDuration = Duration(seconds: 30);
  static const Duration shiftNoticeDuration = Duration(seconds: 4);
  static const List<int> cancelledCookingDisplayOptionsSeconds = <int>[
    15,
    30,
    60,
    120,
  ];
}
