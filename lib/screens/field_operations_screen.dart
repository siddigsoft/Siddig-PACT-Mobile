// lib/screens/field_operations_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/app_menu_overlay.dart';
import '../widgets/map_widget.dart';
import '../widgets/modern_app_header.dart';
import '../widgets/modern_card.dart';

class FieldOperationsScreen extends StatefulWidget {
  const FieldOperationsScreen({super.key});

  @override
  State<FieldOperationsScreen> createState() => _FieldOperationsScreenState();
}

class _FieldOperationsScreenState extends State<FieldOperationsScreen> {
  bool _isOnline = false;
  bool _showMenu = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusCard(),
                          const SizedBox(height: 16),
                          _buildLocationCard(),
                          const SizedBox(height: 24),
                          _buildQuickActionsSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Show menu overlay when menu button is clicked
          if (_showMenu)
            GestureDetector(
              onTap: () {
                setState(() {
                  _showMenu = false;
                });
              },
              child: AppMenuOverlay(
                onClose: () {
                  setState(() {
                    _showMenu = false;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ModernAppHeader(
      title: 'Field Operations',
      actions: [
        HeaderActionButton(
          icon: Icons.notifications_outlined,
          tooltip: 'Notifications',
          backgroundColor: Colors.white,
          color: AppColors.accentYellow,
          onPressed: () {
            HapticFeedback.lightImpact();
            // Show notifications
          },
        ),
        const SizedBox(width: 8),
        HeaderActionButton(
          icon: Icons.menu_rounded,
          tooltip: 'Menu',
          backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
          color: AppColors.primaryBlue,
          onPressed: () {
            HapticFeedback.mediumImpact();
            setState(() {
              _showMenu = true;
            });
          },
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return ModernCard(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 16),
      borderRadius: 20,
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowColor.withOpacity(0.12),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 6),
        ),
      ],
      animationDelay: 100.ms,
      animate: true,
      animationDuration: 500.ms,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.wifi_tethering_rounded,
                  color: AppColors.primaryOrange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Status',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                _isOnline ? 'Online' : 'Offline',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: _isOnline
                      ? AppColors.accentGreen
                      : AppColors.accentRed,
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: _isOnline,
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isOnline = value;
                  });
                },
                activeThumbColor: AppColors.accentGreen,
                activeTrackColor: AppColors.accentGreen.withOpacity(0.3),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: AppColors.accentRed.withOpacity(0.3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return ModernCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowColor.withOpacity(0.15),
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
      ],
      headerLeading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.backgroundGray,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.location_on_outlined,
          color: AppColors.primaryOrange,
          size: 22,
        ),
      ),
      headerTitle: 'Current Location',
      animationDelay: 200.ms,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.backgroundGray,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              // Real map widget using Google Maps
              const MapWidget(height: 180, showUserLocation: true),
              // Floating button overlay
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryOrange.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      // Implement location refresh logic
                    },
                    icon: const Icon(Icons.my_location, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Text(
            'Quick Actions',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildQuickActionCard(
              icon: Icons.camera_alt_outlined,
              title: 'Take Photo',
              color: AppColors.primaryOrange,
              onTap: () {},
            ),
            _buildQuickActionCard(
              icon: Icons.videocam_outlined,
              title: 'Record Video',
              color: AppColors.primaryBlue,
              onTap: () {},
            ),
            _buildQuickActionCard(
              icon: Icons.mic_none_rounded,
              title: 'Voice Note',
              color: AppColors.primaryOrange,
              onTap: () {},
            ),
            _buildQuickActionCard(
              icon: Icons.qr_code_scanner_outlined,
              title: 'Scan Code',
              color: AppColors.primaryBlue,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, color.withOpacity(0.05)],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withOpacity(0.1),
                            color.withOpacity(0.2),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.1),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: color, size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .shimmer(
          delay: 3.seconds,
          duration: 1.seconds,
          color: color.withOpacity(0.1),
        );
  }
}
