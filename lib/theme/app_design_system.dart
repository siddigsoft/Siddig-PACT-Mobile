// lib/theme/app_design_system.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Comprehensive design system for PACT Mobile App
/// Provides consistent spacing, typography, animations, and components
class AppDesignSystem {
  // ============================================
  // SPACING SYSTEM
  // ============================================
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;
  static const double space2XL = 48.0;
  static const double space3XL = 64.0;

  // ============================================
  // BORDER RADIUS
  // ============================================
  static const double radiusXS = 8.0;
  static const double radiusSM = 12.0;
  static const double radiusMD = 16.0;
  static const double radiusLG = 20.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 999.0;

  // ============================================
  // ELEVATION & SHADOWS
  // ============================================
  static List<BoxShadow> shadowSM = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowMD = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> shadowLG = [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> shadowXL = [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];

  // Colored shadows for emphasis
  static List<BoxShadow> shadowOrange = [
    BoxShadow(
      color: AppColors.primaryOrange.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> shadowBlue = [
    BoxShadow(
      color: AppColors.primaryBlue.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // ============================================
  // TYPOGRAPHY
  // ============================================
  static TextStyle get displayLarge => GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
        height: 1.2,
      );

  static TextStyle get displayMedium => GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
        height: 1.3,
      );

  static TextStyle get displaySmall => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
        height: 1.3,
      );

  static TextStyle get headlineLarge => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
        height: 1.4,
      );

  static TextStyle get headlineMedium => GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
        height: 1.4,
      );

  static TextStyle get headlineSmall => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
        height: 1.4,
      );

  static TextStyle get titleLarge => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
        height: 1.5,
      );

  static TextStyle get titleMedium => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
        height: 1.5,
      );

  static TextStyle get bodyLarge => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textDark,
        height: 1.6,
      );

  static TextStyle get bodyMedium => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textDark,
        height: 1.6,
      );

  static TextStyle get bodySmall => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textLight,
        height: 1.6,
      );

  static TextStyle get labelLarge => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
        height: 1.4,
      );

  static TextStyle get labelMedium => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
        height: 1.4,
      );

  static TextStyle get labelSmall => GoogleFonts.poppins(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppColors.textLight,
        height: 1.4,
      );

  // ============================================
  // ANIMATION DURATIONS
  // ============================================
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);

  // ============================================
  // ANIMATION CURVES
  // ============================================
  static const Curve curveDefault = Curves.easeInOut;
  static const Curve curveEmphasized = Curves.easeInOutCubic;
  static const Curve curveSpring = Curves.elasticOut;

  // ============================================
  // CARD STYLES
  // ============================================
  static BoxDecoration cardDecoration({
    Color? color,
    List<BoxShadow>? shadows,
    Gradient? gradient,
    double? radius,
  }) {
    return BoxDecoration(
      color: gradient == null ? (color ?? AppColors.cardBackground) : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius ?? radiusMD),
      boxShadow: shadows ?? shadowMD,
    );
  }

  static BoxDecoration cardOutline({
    Color? borderColor,
    double? borderWidth,
    double? radius,
  }) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius ?? radiusMD),
      border: Border.all(
        color: borderColor ?? AppColors.borderColor,
        width: borderWidth ?? 1,
      ),
    );
  }

  // ============================================
  // BUTTON STYLES
  // ============================================
  static ButtonStyle primaryButton({double? radius}) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryOrange,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius ?? radiusMD),
      ),
      textStyle: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      shadowColor: AppColors.primaryOrange.withOpacity(0.3),
    ).copyWith(
      elevation: WidgetStateProperty.resolveWith<double>(
        (states) => states.contains(WidgetState.pressed) ? 0 : 4,
      ),
    );
  }

  static ButtonStyle secondaryButton({double? radius}) {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.primaryOrange,
      side: const BorderSide(color: AppColors.primaryOrange, width: 2),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius ?? radiusMD),
      ),
      textStyle: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static ButtonStyle textButton() {
    return TextButton.styleFrom(
      foregroundColor: AppColors.primaryOrange,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      textStyle: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static ButtonStyle iconButton({Color? color}) {
    return IconButton.styleFrom(
      foregroundColor: color ?? AppColors.primaryOrange,
      backgroundColor: (color ?? AppColors.primaryOrange).withOpacity(0.1),
      padding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSM),
      ),
    );
  }

  // ============================================
  // INPUT DECORATION
  // ============================================
  static InputDecoration inputDecoration({
    String? label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      errorText: errorText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: BorderSide(color: AppColors.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: BorderSide(color: AppColors.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: AppColors.accentRed, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: AppColors.accentRed, width: 2),
      ),
      labelStyle: GoogleFonts.poppins(
        color: AppColors.textLight,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: GoogleFonts.poppins(
        color: AppColors.textLight.withOpacity(0.6),
      ),
      errorStyle: GoogleFonts.poppins(
        color: AppColors.accentRed,
        fontSize: 12,
      ),
    );
  }

  // ============================================
  // LOADING INDICATOR
  // ============================================
  static Widget loadingIndicator({Color? color, double? size}) {
    return SizedBox(
      width: size ?? 24,
      height: size ?? 24,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? AppColors.primaryOrange,
        ),
      ),
    );
  }

  // ============================================
  // EMPTY STATE
  // ============================================
  static Widget emptyState({
    required IconData icon,
    required String title,
    String? description,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(spaceLG),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(spaceXL),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: AppColors.primaryOrange,
              ),
            ),
            const SizedBox(height: spaceLG),
            Text(
              title,
              style: headlineMedium,
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: spaceSM),
              Text(
                description,
                style: bodyMedium.copyWith(color: AppColors.textLight),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: spaceLG),
              action,
            ],
          ],
        ),
      ),
    );
  }

  // ============================================
  // BADGES
  // ============================================
  static Widget badge({
    required String text,
    Color? backgroundColor,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.primaryOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(radiusFull),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor ?? AppColors.primaryOrange,
        ),
      ),
    );
  }

  // ============================================
  // DIVIDERS
  // ============================================
  static Widget divider({double? height, double? thickness}) {
    return Divider(
      height: height ?? spaceMD,
      thickness: thickness ?? 1,
      color: AppColors.borderColor,
    );
  }

  static Widget verticalDivider({double? width, double? thickness}) {
    return VerticalDivider(
      width: width ?? spaceMD,
      thickness: thickness ?? 1,
      color: AppColors.borderColor,
    );
  }
}
