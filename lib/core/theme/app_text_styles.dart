import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTextStyles {
  static final TextStyle displayTimer = GoogleFonts.inter(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 48 / 48,
    letterSpacing: -0.02 * 48,
  );

  static final TextStyle headlineLg = GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 40 / 32,
  );

  static final TextStyle headlineMd = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
  );

  static final TextStyle bodyLg = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 28 / 18,
  );

  static final TextStyle bodyMd = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  );

  static final TextStyle labelCaps = GoogleFonts.jetBrainsMono(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 20 / 14,
    letterSpacing: 0.05 * 14,
  );

  static final TextStyle headlineLgMobile = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 32 / 24,
  );
}
