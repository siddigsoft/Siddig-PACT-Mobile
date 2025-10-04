// lib/screens/forms_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/mmp_file.dart';
import '../services/mmp_file_service.dart';
import '../theme/app_colors.dart';
import '../widgets/modern_app_header.dart';
import 'package:url_launcher/url_launcher.dart';

class FormsScreen extends StatefulWidget {
  const FormsScreen({super.key});

  @override
  State<FormsScreen> createState() => _FormsScreenState();
}

class _FormsScreenState extends State<FormsScreen> {
  final MMPFileService _mmpFileService = MMPFileService();
  List<MMPFile> _mmpFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMMPFiles();
  }

  Future<void> _loadMMPFiles() async {
    try {
      final files = await _mmpFileService.getMMPFiles();
      if (mounted) {
        setState(() {
          _mmpFiles = files
              .map((f) {
                try {
                  return MMPFile.fromJson(f);
                } catch (e) {
                  debugPrint('Error parsing MMP file: $e');
                  debugPrint('Problematic data: $f');
                  return null;
                }
              })
              .whereType<MMPFile>()
              .toList();
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading MMP files: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading MMP files: ${e.toString()}')),
        );
      }
    }
  }

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
                      _buildSectionTitle('MMP Files'),
                      const SizedBox(height: 12),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _mmpFiles.isEmpty
                          ? Center(
                              child: Text(
                                'No MMP files available',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: AppColors.textLight,
                                ),
                              ),
                            )
                          : _buildMMPFilesList(),
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

  Widget _buildMMPFilesList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _mmpFiles.length,
      itemBuilder: (context, index) {
        final file = _mmpFiles[index];
        return _buildFormItem(
          icon: Icons.file_present_rounded,
          title: file.name ?? 'Unnamed File',
          status: file.status ?? 'Unknown',
          statusColor: _getStatusColor(file.status ?? ''),
          onTap: () => _handleFileTap(file),
          delay: (index * 150).ms,
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.accentYellow;
      case 'approved':
        return AppColors.accentGreen;
      case 'verified':
        return AppColors.primaryBlue;
      case 'rejected':
        return AppColors.errorRed;
      default:
        return AppColors.textLight;
    }
  }

  Future<void> _handleFileTap(MMPFile file) async {
    if (file.fileUrl == null || file.fileUrl!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No file URL available')));
      }
      return;
    }

    try {
      final urlStr = file.fileUrl!.trim();

      // Validate URL format
      if (!urlStr.startsWith('http://') && !urlStr.startsWith('https://')) {
        throw FormatException('Invalid URL format');
      }

      // Try to encode the URL properly
      final uri = Uri.tryParse(urlStr);
      if (uri == null) {
        throw FormatException('Could not parse URL');
      }

      // Validate the URL can be launched
      if (!await canLaunchUrl(uri)) {
        throw Exception('Could not launch URL');
      }

      // Launch in external browser
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${e.toString()}')),
        );
      }
    }
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
