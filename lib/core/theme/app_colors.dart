import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color surface = Color(0xFF0B1326);
  static const Color surfaceDim = Color(0xFF0B1326);
  static const Color surfaceBright = Color(0xFF31394D);
  static const Color surfaceContainerLowest = Color(0xFF060E20);
  static const Color surfaceContainerLow = Color(0xFF131B2E);
  static const Color surfaceContainer = Color(0xFF171F33);
  static const Color surfaceContainerHigh = Color(0xFF222A3D);
  static const Color surfaceContainerHighest = Color(0xFF2D3449);
  static const Color onSurface = Color(0xFFDAE2FD);
  static const Color onSurfaceVariant = Color(0xFFBBCABF);
  static const Color inverseSurface = Color(0xFFDAE2FD);
  static const Color inverseOnSurface = Color(0xFF283044);
  static const Color outline = Color(0xFF86948A);
  static const Color outlineVariant = Color(0xFF3C4A42);
  static const Color surfaceTint = Color(0xFF4EDEA3);
  static const Color primary = Color(0xFF4EDEA3);
  static const Color onPrimary = Color(0xFF003824);
  static const Color primaryContainer = Color(0xFF10B981);
  static const Color onPrimaryContainer = Color(0xFF00422B);
  static const Color inversePrimary = Color(0xFF006C49);
  static const Color secondary = Color(0xFFFFB3AD);
  static const Color onSecondary = Color(0xFF68000A);
  static const Color secondaryContainer = Color(0xFFA40217);
  static const Color onSecondaryContainer = Color(0xFFFFAEA8);
  static const Color tertiary = Color(0xFFFFB3AF);
  static const Color onTertiary = Color(0xFF650911);
  static const Color tertiaryContainer = Color(0xFFFC7C78);
  static const Color onTertiaryContainer = Color(0xFF711419);
  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);
  static const Color primaryFixed = Color(0xFF6FFBBE);
  static const Color primaryFixedDim = Color(0xFF4EDEA3);
  static const Color onPrimaryFixed = Color(0xFF002113);
  static const Color onPrimaryFixedVariant = Color(0xFF005236);
  static const Color secondaryFixed = Color(0xFFFFDAD7);
  static const Color secondaryFixedDim = Color(0xFFFFB3AD);
  static const Color onSecondaryFixed = Color(0xFF410004);
  static const Color onSecondaryFixedVariant = Color(0xFF930013);
  static const Color tertiaryFixed = Color(0xFFFFDAD7);
  static const Color tertiaryFixedDim = Color(0xFFFFB3AF);
  static const Color onTertiaryFixed = Color(0xFF410005);
  static const Color onTertiaryFixedVariant = Color(0xFF842225);
  static const Color background = Color(0xFF0B1326);
  static const Color onBackground = Color(0xFFDAE2FD);
  static const Color surfaceVariant = Color(0xFF2D3449);

  // KDS semantic status / urgency (from desktop reference + plan).
  static const Color statusNew = Color(0xFF475569);
  /// Lighter slate for dark boards so new-order headers stay distinct.
  static const Color statusNewOnDark = Color(0xFF64748B);
  static const Color statusCooking = Color(0xFFF97316);
  static const Color statusCompleted = Color(0xFF64748B);
  /// Muted cancelled header — distinct from urgency critical red.
  static const Color statusCancelled = Color(0xFF9CA3AF);
  static const Color urgencyWarning = Color(0xFFF59E0B);
  static const Color urgencyCritical = Color(0xFFEF4444);
  static const Color statusTabActive = Color(0xFF10B981);
  static const Color onStatusHeader = Color(0xFFFFFFFF);

  // Always-dark chrome (top bar + sidebar) — theme-independent.
  static const Color chromeHeader = Color(0xFF0F172A);
  static const Color chromeSidebar = Color(0xFF1E293B);
  static const Color chromeBorder = Color(0xFF334155);
  static const Color chromeOnSurface = Color(0xFFE2E8F0);
  static const Color chromeOnSurfaceMuted = Color(0xFF94A3B8);
  static const Color chromeOnSurfaceDim = Color(0xFF64748B);
  static const Color chromeBadgeBackground = Color(0xFF334155);

  // Light KDS board surfaces (screen.png reference).
  static const Color lightBackground = Color(0xFFF3F4F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF111827);
  static const Color lightOnSurfaceVariant = Color(0xFF6B7280);
  static const Color lightOutline = Color(0xFFE2E8F0);
  static const Color lightHeader = Color(0xFF0F172A);
  static const Color lightSidebar = Color(0xFF1E293B);
  static const Color lightCardMuted = Color(0xFFF9FAFB);
}
