// lib/screens/wallet_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/modern_app_header.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: Column(
          children: [
            ModernAppHeader(
              title: 'Wallet',
              actions: [],
            ),
            Expanded(
              child: _buildComingSoonBanner(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComingSoonBanner() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryOrange.withOpacity(0.2),
                      AppColors.primaryBlue.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: -5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.wallet_giftcard,
                  size: 60,
                  color: AppColors.primaryOrange,
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.1, 1.1),
                    duration: 2000.ms,
                    curve: Curves.easeInOut,
                  )
                  .then()
                  .scale(
                    begin: const Offset(1.1, 1.1),
                    end: const Offset(1, 1),
                    duration: 2000.ms,
                    curve: Curves.easeInOut,
                  ),

              const SizedBox(height: 32),

              // Coming Soon Text with gradient
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryOrange,
                    AppColors.primaryBlue,
                  ],
                ).createShader(bounds),
                child: Text(
                  'Coming Soon',
                  style: GoogleFonts.poppins(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ).animate().fadeIn(duration: 800.ms).slideY(
                  begin: 0.3,
                  end: 0,
                  duration: 800.ms,
                  curve: Curves.easeOutQuad),

              const SizedBox(height: 16),

              // Subtitle
              Text(
                'Manage your earnings and transactions',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 800.ms, delay: 200.ms).slideY(
                  begin: 0.3,
                  end: 0,
                  duration: 800.ms,
                  curve: Curves.easeOutQuad),

              const SizedBox(height: 48),

              // Feature preview cards
              _buildFeatureCard(
                icon: Icons.trending_up,
                title: 'Earnings Dashboard',
                description: 'Track your earnings over time',
                delay: 400.ms,
              ),

              const SizedBox(height: 16),

              _buildFeatureCard(
                icon: Icons.swap_horiz,
                title: 'Transaction History',
                description: 'View all your payments and transfers',
                delay: 600.ms,
              ),

              const SizedBox(height: 16),

              _buildFeatureCard(
                icon: Icons.account_balance_wallet,
                title: 'Instant Payouts',
                description: 'Withdraw your earnings anytime',
                delay: 800.ms,
              ),

              const SizedBox(height: 48),

              // Decorative elements
              Container(
                height: 2,
                width: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryOrange.withOpacity(0),
                      AppColors.primaryOrange,
                      AppColors.primaryOrange.withOpacity(0),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ).animate().fadeIn(duration: 800.ms, delay: 1000.ms),

              const SizedBox(height: 16),

              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentYellow.withOpacity(0.1),
                  border: Border.all(
                    color: AppColors.accentYellow,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.accentYellow,
                        shape: BoxShape.circle,
                      ),
                    )
                        .animate(onPlay: (controller) => controller.repeat())
                        .fade(duration: 1500.ms)
                        .then()
                        .fade(duration: 1500.ms),
                    const SizedBox(width: 8),
                    Text(
                      'Launching Soon',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.accentYellow,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 800.ms, delay: 1200.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Duration delay,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.primaryOrange.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryOrange.withOpacity(0.2),
                  AppColors.primaryBlue.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryOrange,
              size: 24,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms, delay: delay).slideX(
        begin: -0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuad);
  }
}
