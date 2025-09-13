// lib/theme/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors - These are your company's brand colors
  static const Color primaryOrange = Color(0xFFFF6B35);  // Accented orange - vibrant and energetic
  static const Color primaryBlue = Color(0xFF4A90E2);    // Accented blue - professional and trustworthy
  static const Color primaryWhite = Color(0xFFFFFFFF);   // Pure white for clean backgrounds
  
  // Secondary Colors - Supporting colors for better UI
  static const Color lightOrange = Color(0xFFFFA574);    // Lighter shade of orange for hover states
  static const Color darkOrange = Color(0xFFE55100);     // Darker shade for pressed states
  static const Color lightBlue = Color(0xFF7BB3F0);      // Lighter blue for secondary elements
  static const Color darkBlue = Color(0xFF2E5C8A);       // Darker blue for emphasis
  
  // Neutral Colors - For text and backgrounds
  static const Color textDark = Color(0xFF2C3E50);       // Dark gray for primary text
  static const Color textLight = Color(0xFF7F8C8D);      // Light gray for secondary text
  static const Color backgroundGray = Color(0xFFF9FAFB); // Ultra light gray for backgrounds - slightly lighter for modern look
  static const Color borderColor = Color(0xFFEDF2F7);    // Subtle border color for modern design
  
  // New Accent Colors - For modern UI elements
  static const Color accentGreen = Color(0xFF2ECC71);    // Success color
  static const Color accentRed = Color(0xFFE74C3C);      // Error color
  static const Color accentYellow = Color(0xFFF39C12);   // Warning color
  static const Color cardBackground = Color(0xFFFEFEFE); // Slightly off-white for card backgrounds
  static const Color shadowColor = Color(0x14000000);    // Subtle shadow color (8% opacity)
  
  // Gradient definitions - For beautiful backgrounds
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryOrange, lightOrange],
  );
  
  // Modern frosted glass effect
  static Color get frostedGlass => Colors.white.withOpacity(0.75);
  
  // Modern card decoration
  static BoxDecoration get modernCardDecoration => BoxDecoration(
    color: cardBackground,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: shadowColor,
        blurRadius: 20,
        spreadRadius: 0,
        offset: const Offset(0, 4),
      ),
    ],
  );
  
  // Modern button decoration
  static BoxDecoration get modernButtonDecoration => BoxDecoration(
    gradient: primaryGradient,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: primaryOrange.withOpacity(0.25),
        blurRadius: 12,
        spreadRadius: 0,
        offset: const Offset(0, 4),
      ),
    ],
  );
  
  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, lightBlue],
  );
}