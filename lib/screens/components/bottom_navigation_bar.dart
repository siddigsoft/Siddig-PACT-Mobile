// lib/screens/components/bottom_navigation_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isCoordinator;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isCoordinator = false,
  });

  @override
  Widget build(BuildContext context) {
    // Get screen width to calculate positions
    final screenWidth = MediaQuery.of(context).size.width;
    // Get bottom safe area padding (includes system navigation bar)
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    // Calculate number of items based on role
    final itemCount = isCoordinator ? 6 : 5;

    return Container(
      // Add padding for system navigation bar
      padding: EdgeInsets.only(bottom: bottomSafeArea),
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
            left: (screenWidth / itemCount) * currentIndex + (screenWidth / (itemCount * 2)) - 24,
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
                children: _buildNavItems(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  List<Widget> _buildNavItems(BuildContext context) {
    final items = <Widget>[
      _buildNavItem(0, AppLocalizations.of(context)!.home, Icons.home_outlined),
      _buildNavItem(1, 'Reports', Icons.bar_chart_outlined),
      _buildNavItem(2, AppLocalizations.of(context)!.safety, Icons.shield_outlined),
      _buildNavItem(3, AppLocalizations.of(context)!.chat, Icons.chat_bubble_outline),
      _buildNavItem(4, 'Wallet', Icons.wallet_giftcard),
    ];
    
    // Add verification tab for coordinators
    if (isCoordinator) {
      items.add(_buildNavItem(5, 'Verify', Icons.verified_user_outlined));
    }
    
    return items;
  }

  // Helper method to get the active color based on tab index
  Color _getActiveColor(int index) {
    switch (index) {
      case 2:
        return AppColors.accentGreen;
      case 3:
      case 4:
        return AppColors.primaryBlue;
      case 5:
        return AppColors.primaryOrange; // Verification tab
      default:
        return AppColors.primaryOrange;
    }
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final isActive = currentIndex == index;
    final activeColor = _getActiveColor(index);
    // Smaller width for 6 items
    final itemWidth = isCoordinator ? 55.0 : 65.0;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: itemWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isCoordinator ? 6 : 8),
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
                size: isActive ? (isCoordinator ? 22 : 24) : (isCoordinator ? 20 : 22),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: isActive ? activeColor : AppColors.textLight,
                  fontSize: isCoordinator ? 10 : 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
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
            color: isActive ? activeColor.withOpacity(0.1) : Colors.transparent,
          ),
    );
  }
}
