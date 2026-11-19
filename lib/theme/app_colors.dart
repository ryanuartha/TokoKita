import 'package:flutter/material.dart';

/// Design Tokens berdasarkan PRD-Sistem-Desain-Visual-Ecommerce.pdf
class AppColors {
  AppColors._();

  // Primary Brand Color & Gradient (PRD Section 3A)
  static const Color primary = Color(0xFFEE4D2D);
  static const Color primaryDark = Color(0xFFD03B1E);
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFF53D2D), Color(0xFFFF6633)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Secondary Brand Colors
  static const Color secondaryMall = Color(
    0xFFD0011B,
  ); // Badge Official Store / Mall
  static const Color secondaryMen = Color(
    0xFF113366,
  ); // Kategori Pria / Premium

  // Accent & Functional Colors
  static const Color accentTeal = Color(
    0xFF00BFA5,
  ); // Badge Gratis Ongkir / Success
  static const Color accentTealLight = Color(
    0xFFD1F4EF,
  ); // Background tint alert/label

  // Aliases untuk kompatibilitas UI
  static const Color accent = Color(0xFFEE4D2D);
  static const Color accentSoft = Color(0xFFFFF1F0);
  static const Color primaryAccent = Color(0xFFEE4D2D);
  static const Color secondaryAccent = Color(0xFF00BFA5);
  static const Color borderFocused = Color(0xFFEE4D2D);

  // Surface & Canvas Backgrounds (PRD Section 3A)
  static const Color background = Color(
    0xFFF5F5F5,
  ); // Base canvas grey (#F5F5F5)
  static const Color cardSurface = Color(
    0xFFFFFFFF,
  ); // Pure white card (#FFFFFF)
  static const Color border = Color(0xFFE0E0E0); // Divider border

  // Neutral Typography Colors (PRD Section 3A)
  static const Color textPrimary = Color(
    0xFF222222,
  ); // Heading & important text (#222222)
  static const Color textSecondary = Color(
    0xFF757575,
  ); // Subtitle & metadata (#757575)
  static const Color textMuted = Color(0xFF9E9E9E); // Disabled & subtle text
  static const Color starYellow = Color(0xFFFFC107); // Star rating

  // Semantic Stock & Status Colors
  static const Color stockAvailableBg = Color(0xFFD1F4EF);
  static const Color stockAvailableText = Color(0xFF00BFA5);
  static const Color stockLowBg = Color(0xFFFEF3C7);
  static const Color stockLowText = Color(0xFFD97706);
  static const Color stockEmptyBg = Color(0xFFEEEEEE);
  static const Color stockEmptyText = Color(0xFF757575);
}
