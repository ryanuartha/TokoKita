import 'package:material_ui/material_ui.dart';
import 'app_colors.dart';

/// Skala Tipografi Berdasarkan PRD Section 3B
/// Font sistem netral System Sans-Serif sesuai panduan TokoKita.
class AppTypography {
  AppTypography._();

  // Heading-1: Plus Jakarta Sans Bold (700) 20px / 28px
  static const TextStyle heading1 = TextStyle(
    fontFamily: 'sans-serif',
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.4,
    letterSpacing: -0.3,
  );

  static const TextStyle heroTitle = heading1;
  static const TextStyle screenTitle = heading1;

  // Section Title
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: 'sans-serif',
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  // Price-Tag: Plus Jakarta Sans SemiBold (600) 16px / 22px
  static const TextStyle priceTag = TextStyle(
    fontFamily: 'sans-serif',
    color: AppColors.primary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.37,
  );

  static const TextStyle price = priceTag;
  static const TextStyle discountPrice = priceTag;

  // Body-Regular: Roboto Regular (400) 14px / 20px
  static const TextStyle bodyRegular = TextStyle(
    fontFamily: 'sans-serif',
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.42,
  );

  static const TextStyle body = bodyRegular;
  static const TextStyle cardTitle = TextStyle(
    fontFamily: 'sans-serif',
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  // Subtitle Metadata
  static const TextStyle subtitle = TextStyle(
    fontFamily: 'sans-serif',
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  // Caption-Badge: Roboto Medium (500) 11px / 14px
  static const TextStyle captionBadge = TextStyle(
    fontFamily: 'sans-serif',
    color: Colors.white,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.27,
  );

  static const TextStyle badge = captionBadge;
  static const TextStyle originalPrice = TextStyle(
    fontFamily: 'Roboto',
    color: AppColors.textSecondary,
    fontSize: 11,
    decoration: TextDecoration.lineThrough,
  );
}
