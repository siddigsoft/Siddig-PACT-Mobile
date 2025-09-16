// lib/screens/equipment_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class EquipmentScreen extends StatelessWidget {
  const EquipmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFilterChips(),
                      const SizedBox(height: 16),
                      _buildEquipmentItem(
                        name: 'Generator 1',
                        status: 'OK',
                        isCheckedIn: true,
                        nextMaintenance: '2024-07-15',
                        statusColor: AppColors.accentGreen,
                      ),
                      _buildEquipmentItem(
                        name: 'Pump 2',
                        status: 'Needs Service',
                        isCheckedIn: false,
                        nextMaintenance: '2024-08-20',
                        statusColor: AppColors.accentRed,
                      ),
                      _buildEquipmentItem(
                        name: 'Compressor 3',
                        status: 'OK',
                        isCheckedIn: true,
                        nextMaintenance: '2024-09-05',
                        statusColor: AppColors.accentGreen,
                      ),
                      _buildEquipmentItem(
                        name: 'Welder 4',
                        status: 'OK',
                        isCheckedIn: false,
                        nextMaintenance: '2024-10-10',
                        statusColor: AppColors.accentGreen,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          // Add new equipment
        },
        backgroundColor: AppColors.primaryOrange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 8, top: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundGray,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                // Navigation logic would go here
              },
              icon: const Icon(Icons.arrow_back),
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Equipment',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              // Filter functionality
            },
            icon: Icon(
              Icons.filter_list,
              color: AppColors.primaryOrange,
              size: 28,
            ),
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              // Search functionality
            },
            icon: Icon(Icons.search, color: AppColors.primaryOrange, size: 28),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip('All', true),
          _buildFilterChip('Available', false),
          _buildFilterChip('In Use', false),
          _buildFilterChip('Needs Maintenance', false),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 100.ms);
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        selectedColor: AppColors.primaryOrange.withOpacity(0.1),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected ? AppColors.primaryOrange : AppColors.borderColor,
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        label: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.primaryOrange : AppColors.textLight,
          ),
        ),
        onSelected: (value) {
          // Update filter selection
        },
      ),
    );
  }

  Widget _buildEquipmentItem({
    required String name,
    required String status,
    required bool isCheckedIn,
    required String nextMaintenance,
    required Color statusColor,
  }) {
    return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: status == 'OK'
                            ? AppColors.accentGreen.withOpacity(0.1)
                            : AppColors.accentRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.build_outlined,
                        color: status == 'OK'
                            ? AppColors.accentGreen
                            : AppColors.accentRed,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  status == 'OK'
                                      ? Icons.check_circle
                                      : Icons.warning,
                                  color: statusColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    status,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: statusColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Wrapped in a container with constraints to prevent overflow
                    Container(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              isCheckedIn ? 'Checked-in' : 'Checked-out',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textLight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: isCheckedIn,
                            onChanged: (value) {
                              // Update check-in status
                            },
                            activeThumbColor: AppColors.primaryOrange,
                            activeTrackColor: AppColors.primaryOrange
                                .withOpacity(0.3),
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: AppColors.textLight.withOpacity(
                              0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min, // Prevent unnecessary stretching
                  children: [
                    Text(
                      'Next Maintenance: ',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textLight,
                      ),
                    ),
                    Flexible(
                      // Allow text to wrap if needed
                      child: Text(
                        nextMaintenance,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 200.ms)
        .slideY(begin: 0.1, end: 0, duration: 300.ms);
  }
}
