import 'package:flutter/material.dart';

class AppColors {
  // Material 3 light color scheme.
  static const Color lightPrimary = Color(0xFF1E384F);
  static const Color lightSecondary = Color(0xFFB6B5BA);
  static const Color lightTertiary = Color(0xFF3771A1);
  static const Color lightSurface = Color(0xFFFAFAFA);
  static const Color lightError = Color(0xFFB3261E);
  static const Color lightErrorContainer = Color(0xFFF2C6C0);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightOnSecondary = Color(0xFF1A1B1F);
  static const Color lightOnTertiary = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF1A1B1F);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightOnErrorContainer = Color(0xFF410E0B);

  // Material 3 dark color scheme. These retain the light-theme source hues
  // while raising accent tones and lowering the surface tone for contrast.
  static const Color darkPrimary = Color(0xFFA8C7E0);
  static const Color darkSecondary = Color(0xFFC7C5CB);
  static const Color darkTertiary = Color(0xFF94C1EA);
  static const Color darkSurface = Color(0xFF1A1D22);
  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkErrorContainer = Color(0xFF93000A);
  static const Color darkOnPrimary = Color(0xFF1A1D22);
  static const Color darkOnSecondary = Color(0xFF1A1D22);
  static const Color darkOnTertiary = Color(0xFF1A1D22);
  static const Color darkOnSurface = Color(0xFFE3E2E6);
  static const Color darkOnError = Color(0xFF690005);
  static const Color darkOnErrorContainer = Color(0xFFFFDAD6);

  // Compatibility aliases for existing feature-level color usages.
  static const Color primary = lightPrimary;
  static const Color primaryLight = lightPrimary;
  static const Color primaryDark = darkPrimary;

  // Semantic colors
  static const Color success = Color(0xFF22C55E); // Green - all complete
  static const Color error = lightError; // Red - incomplete
  static const Color warning = Color(0xFFF59E0B); // Orange - selected date
  static const Color info = Color(0xFF3B82F6); // Blue

  // Retained aliases for callers that distinguish background from surface.
  static const Color lightBackground = lightSurface;
  static const Color lightOnBackground = lightOnSurface;
  static const Color darkBackground = darkSurface;
  static const Color darkOnBackground = darkOnSurface;

  // Calendar pastel colors for date indicators
  static const Color pastelGreen = Color(0xFF86EFAC); // activities completed
  static const Color pastelRed = Color(
    0xFFFCA5A5,
  ); // activities missed (past + incomplete)
  static const Color pastelPrimary = Color(
    0xFFA5B4FC,
  ); // activity exists (scheduled)
}
