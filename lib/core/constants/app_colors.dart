import 'package:flutter/material.dart';

class AppColors {
  // Primary brand color
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);

  // Semantic colors
  static const Color success = Color(0xFF22C55E); // Green - all complete
  static const Color error = Color(0xFFEF4444); // Red - incomplete
  static const Color warning = Color(0xFFF59E0B); // Orange - selected date
  static const Color info = Color(0xFF3B82F6); // Blue

  // Light theme colors
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnBackground = Color(0xFF1E293B);
  static const Color lightOnSurface = Color(0xFF334155);

  // Dark theme colors
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkOnBackground = Color(0xFFF1F5F9);
  static const Color darkOnSurface = Color(0xFFCBD5E1);

  // Calendar pastel colors for date indicators
  static const Color pastelGreen = Color(0xFF86EFAC);   // activities completed
  static const Color pastelRed = Color(0xFFFCA5A5);     // activities missed (past + incomplete)
  static const Color pastelPrimary = Color(0xFFA5B4FC);  // activity exists (scheduled)
}
