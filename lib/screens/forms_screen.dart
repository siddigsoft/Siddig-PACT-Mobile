// lib/screens/forms_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/modern_app_header.dart';

class FormsScreen extends StatelessWidget {
  const FormsScreen({super.key});

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
                      _buildSectionTitle('Available Forms'),
                      const SizedBox(height: 12),
                      _buildFormsList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return ModernAppHeader(
      title: 'Forms',
      showBackButton: true,
      onLeadingIconPressed: () {
        HapticFeedback.lightImpact();
        // Navigation logic would go here
      },
      actions: [
        HeaderActionButton(
          icon: Icons.filter_list_rounded,
          tooltip: 'Filter Forms',
          onPressed: () {
            HapticFeedback.lightImpact();
            // Search functionality would go here
          },
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 100.ms);
  }

  Widget _buildFormsList() {
    return Column(
      children: [
        _buildFormItem(
          icon: Icons.checklist_rounded,
          title: 'Safety Checklist',
          status: 'Pending',
          statusColor: AppColors.accentYellow,
          onTap: () {},
          delay: 0.ms,
        ),
        _buildFormItem(
          icon: Icons.build_outlined,
          title: 'Equipment Report',
          status: 'Completed',
          statusColor: AppColors.accentGreen,
          onTap: () {},
          delay: 150.ms,
        ),
        _buildFormItem(
          icon: Icons.article_outlined,
          title: 'Daily Log',
          status: 'In Progress',
          statusColor: AppColors.primaryBlue,
          onTap: () {},
          delay: 300.ms,
        ),
      ],
    );
  }

  Widget _buildFormItem({
    required IconData icon,
    required String title,
    required String status,
    required Color statusColor,
    required VoidCallback onTap,
    required Duration delay,
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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                onTap();
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundGray,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: AppColors.textDark, size: 28)
                          .animate(
                            onPlay: (controller) =>
                                controller.repeat(reverse: true),
                          )
                          .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.15, 1.15),
                            duration: 2.seconds,
                            curve: Curves.easeInOut,
                          ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                  .animate(
                                    onPlay: (controller) => controller.repeat(),
                                  )
                                  .shimmer(
                                    duration: 1.5.seconds,
                                    color: Colors.white.withOpacity(0.6),
                                  )
                                  .animate() // Add a second animation
                                  .scaleXY(
                                    begin: 0.8,
                                    end: 1.2,
                                    duration: 1.seconds,
                                  )
                                  .then()
                                  .scaleXY(
                                    begin: 1.2,
                                    end: 0.8,
                                    duration: 1.seconds,
                                  ),
                              const SizedBox(width: 6),
                              Text(
                                status,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textLight,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate(delay: delay)
        .fadeIn(duration: 600.ms)
        .slideX(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOut)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }
}
