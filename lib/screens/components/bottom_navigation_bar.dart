// lib/screens/components/bottom_navigation_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Get screen width to calculate positions
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -5),
            spreadRadius: -2,
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          // Animated indicator for selected item
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: (screenWidth / 5) * currentIndex + (screenWidth / 10) - 24,
            top: 8,
            child: Container(
              width: 48,
              height: 3,
              decoration: BoxDecoration(
                color: _getActiveColor(currentIndex),
                borderRadius: BorderRadius.circular(1.5),
                boxShadow: [
                  BoxShadow(
                    color: _getActiveColor(currentIndex).withOpacity(0.5),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                    spreadRadius: -1,
                  ),
                ],
              ),
            ),
          ),
          // Navigation items
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, 'Home', Icons.home_outlined),
                  _buildNavItem(1, 'Forms', Icons.article_outlined),
                  _buildNavItem(2, 'Equipment', Icons.build_outlined),
                  _buildNavItem(3, 'Safety', Icons.shield_outlined),
                  _buildNavItem(4, 'Chat', Icons.chat_bubble_outline),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get the active color based on tab index
  Color _getActiveColor(int index) {
    switch (index) {
      case 3:
        return AppColors.accentGreen;
      case 4:
        return AppColors.primaryBlue;
      default:
        return AppColors.primaryOrange;
    }
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final isActive = currentIndex == index;
    final activeColor = _getActiveColor(index);

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child:
          SizedBox(
                width: 65,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? activeColor.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: activeColor.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                  spreadRadius: -2,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        icon,
                        color: isActive ? activeColor : AppColors.textLight,
                        size: isActive ? 24 : 22,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: GoogleFonts.poppins(
                          color: isActive ? activeColor : AppColors.textLight,
                          fontSize: 11,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .animate(target: isActive ? 1 : 0)
              .scale(
                begin: const Offset(0.92, 0.92),
                end: const Offset(1, 1),
                curve: Curves.easeOutQuint,
                duration: 300.ms,
              )
              .shimmer(
                duration: isActive ? 1200.ms : 0.ms,
                color: isActive
                    ? activeColor.withOpacity(0.1)
                    : Colors.transparent,
              ),
    );
  }
}
