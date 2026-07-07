import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF0D1025);
  static const Color secondaryBackground = Color(0xFF181C35);
  static const Color card = Color(0xFF1F2343);

  // Primaries & Accents
  static const Color primary = Color(0xFF6D6AFB);
  static const Color primaryDark = Color(0xFF5451E8);
  static const Color accent = Color(0xFF8D8BFF);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA5AAC5);

  // Borders
  static const Color border = Color(0x14FFFFFF); // rgba(255,255,255,.08)

  // Status Colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
