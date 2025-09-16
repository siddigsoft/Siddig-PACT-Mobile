// lib/widgets/modern_app_header.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class ModernAppHeader extends StatelessWidget {
  final String title;
  final IconData? leadingIcon;
  final VoidCallback? onLeadingIconPressed;
  final List<Widget>? actions;
  final bool showBackButton;
  final bool centerTitle;
  final Color? backgroundColor;
  final Color? textColor;

  const ModernAppHeader({
    super.key,
    required this.title,
    this.leadingIcon,
    this.onLeadingIconPressed,
    this.actions,
    this.showBackButton = false,
    this.centerTitle = false,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: centerTitle
              ? MainAxisAlignment.center
              : MainAxisAlignment.spaceBetween,
          children: [
            if (showBackButton || leadingIcon != null)
              _buildLeadingButton(context)
            else if (centerTitle)
              const Spacer(flex: 1),

            Expanded(
              flex: 4,
              child:
                  Text(
                        title,
                        textAlign: centerTitle
                            ? TextAlign.center
                            : TextAlign.left,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: textColor ?? AppColors.textDark,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(
                        begin: 0.2,
                        end: 0,
                        duration: 400.ms,
                        curve: Curves.easeOutQuad,
                      ),
            ),

            if (actions != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: actions!.map((action) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: action,
                  );
                }).toList(),
              )
            else if (centerTitle)
              const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingButton(BuildContext context) {
    return Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: (backgroundColor == Colors.white || backgroundColor == null)
                ? AppColors.backgroundGray
                : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor.withOpacity(0.08),
                blurRadius: 8,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.lightImpact();
                if (onLeadingIconPressed != null) {
                  onLeadingIconPressed!();
                } else if (showBackButton) {
                  Navigator.pop(context);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  leadingIcon ?? Icons.arrow_back_ios_rounded,
                  color: textColor ?? AppColors.textDark,
                  size: 22,
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(
          begin: -0.2,
          end: 0,
          duration: 400.ms,
          curve: Curves.easeOutQuad,
        );
  }
}

// Action button builder for consistent styling
class HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? color;
  final Color? backgroundColor;

  const HeaderActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.backgroundGray,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor.withOpacity(0.08),
                blurRadius: 8,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.lightImpact();
                onPressed();
              },
              child: Tooltip(
                message: tooltip ?? '',
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    icon,
                    color: color ?? AppColors.textDark,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: 400.ms,
          curve: Curves.easeOutQuad,
        );
  }
}
