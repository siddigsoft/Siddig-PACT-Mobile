import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../providers/sync_provider.dart';
import '../theme/app_design_system.dart';
import '../theme/app_colors.dart';
import '../widgets/app_widgets.dart';
import '../utils/error_handler.dart';

class CustomDrawerMenu extends StatelessWidget {
  final User? currentUser;
  final VoidCallback onClose;

  const CustomDrawerMenu({
    super.key,
    required this.currentUser,
    required this.onClose,
  });

  Future<void> _launchUrl(
      BuildContext context, String urlString, String errorMessage) async {
    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: try without checking
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Show error message to user
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: errorMessage,
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _launchPactWebsite(BuildContext context) async {
    await _launchUrl(
      context,
      'https://pactorg1.com/about/',
      'Unable to open website. Please check your internet connection.',
    );
  }

  Future<void> _launchPactDashboard(BuildContext context) async {
    await _launchUrl(
      context,
      'https://pact-dashboard-831y.vercel.app/',
      'Unable to open PACT Dashboard. Please check your internet connection.',
    );
  }

  Future<void> _sendFeedback(BuildContext context) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'francis.b.kaz@gmail.com',
      queryParameters: {
        'subject': 'PACT Mobile App Feedback',
        'body':
            'Dear Developer,\n\nI would like to provide feedback about the PACT Mobile app:\n\n'
      },
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        // Fallback: try without checking
        await launchUrl(emailLaunchUri);
      }
    } catch (e) {
      // Show error message to user
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message:
              'Unable to open email app. Please check if you have an email app installed.',
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _performSync(BuildContext context) async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    try {
      // Show initial sync message
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: 'Starting data synchronization...',
          type: SnackBarType.info,
        );
      }

      // Perform full sync
      await syncProvider.performFullSync();

      // Show success message
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: 'Data synchronization completed successfully!',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: 'Sync failed: ${e.toString()}',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = currentUser?.userMetadata?['full_name'] ?? 'User';
    final userEmail = currentUser?.email ?? '';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    final userRole = currentUser?.userMetadata?['role'] ?? 'User';

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              AppColors.lightOrange.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            // Enhanced Header with Gradient
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                boxShadow: AppDesignSystem.shadowMD,
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // User Avatar with Ring
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 32,
                              backgroundColor: Colors.white,
                              child: Text(
                                userInitial,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryOrange,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          // PACT Logo Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: const Text(
                              'PACT',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // User Name
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // User Email
                      Text(
                        userEmail,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // User Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          userRole,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildMenuSection(
                    context,
                    title: 'Quick Access',
                    items: [
                      _MenuItemData(
                        icon: Icons.dashboard_rounded,
                        title: 'PACT Dashboard',
                        subtitle: 'Open web portal',
                        iconColor: AppColors.primaryOrange,
                        onTap: () async {
                          await _launchPactDashboard(context);
                          onClose();
                        },
                      ),
                      _MenuItemData(
                        icon: Icons.sync_rounded,
                        title: 'Sync Data',
                        subtitle: 'Update local data',
                        iconColor: Colors.blue,
                        onTap: () async {
                          await _performSync(context);
                          onClose();
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24, indent: 16, endIndent: 16),
                  _buildMenuSection(
                    context,
                    title: 'Information',
                    items: [
                      _MenuItemData(
                        icon: Icons.info_rounded,
                        title: 'About PACT',
                        subtitle: 'Learn more about us',
                        iconColor: Colors.green,
                        onTap: () async {
                          await _launchPactWebsite(context);
                          onClose();
                        },
                      ),
                      _MenuItemData(
                        icon: Icons.help_rounded,
                        title: 'Help & Support',
                        subtitle: 'Send us feedback',
                        iconColor: Colors.purple,
                        onTap: () async {
                          await _sendFeedback(context);
                          onClose();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Sign Out Button
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.shade400,
                    Colors.red.shade600,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final shouldSignOut = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Sign Out'),
                        content:
                            const Text('Are you sure you want to sign out?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );

                    if (shouldSignOut == true) {
                      await AuthService().signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacementNamed('/login');
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.exit_to_app_rounded,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Sign Out',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // App Version
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'PACT Mobile v1.0.0',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(
    BuildContext context, {
    required String title,
    required List<_MenuItemData> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...items.map((item) => _buildMenuItem(context, item)),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, _MenuItemData item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    color: item.iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      if (item.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItemData {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  _MenuItemData({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.iconColor,
    required this.onTap,
  });
}
