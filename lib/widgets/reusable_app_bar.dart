// lib/widgets/reusable_app_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'modern_app_header.dart';
import 'language_switcher.dart';
import '../services/user_notification_service.dart';
import '../services/notification_service.dart';
import '../models/user_notification.dart';
import '../theme/app_colors.dart';

/// A reusable AppBar widget that can be used across all pages.
/// 
/// This widget automatically handles:
/// - Displaying the page title
/// - Showing drawer icon if scaffoldKey is provided
/// - Showing back button if Navigator can pop and no drawer is available
/// - Optional language switcher
/// - Optional notifications icon with badge
/// - Optional user avatar
/// - Accepting custom actions for additional buttons
/// 
/// Example usage with all features:
/// ```dart
/// final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
/// 
/// Scaffold(
///   key: _scaffoldKey,
///   drawer: CustomDrawerMenu(...),
///   body: Column(
///     children: [
///       ReusableAppBar(
///         title: 'My Page',
///         scaffoldKey: _scaffoldKey,
///         showLanguageSwitcher: true,
///         showNotifications: true,
///         onNotificationTap: () => _showNotificationsPanel(),
///         showUserAvatar: true,
///         onAvatarTap: () => Navigator.push(...),
///       ),
///       // Rest of content
///     ],
///   ),
/// )
/// ```
/// 
/// Example usage with minimal features:
/// ```dart
/// ReusableAppBar(
///   title: 'Details',
///   showBackButton: true,
/// )
/// ```
class ReusableAppBar extends StatelessWidget {
  /// The page title to display
  final String title;
  
  /// Optional scaffold key to control drawer opening/closing
  /// If provided, a drawer icon will be shown on the left
  final GlobalKey<ScaffoldState>? scaffoldKey;
  
  /// Optional list of action buttons to display on the right
  /// These will be shown before the built-in actions (notifications, language, avatar)
  final List<Widget>? actions;
  
  /// Whether to center the title
  final bool centerTitle;
  
  /// Background color of the AppBar
  final Color? backgroundColor;
  
  /// Text color of the title
  final Color? textColor;
  
  /// Custom callback for leading icon press (overrides default drawer/back behavior)
  final VoidCallback? onLeadingIconPressed;
  
  /// Whether to show a back button explicitly
  final bool showBackButton;
  
  /// Whether to show the language switcher
  final bool showLanguageSwitcher;
  
  /// Whether to show the notifications icon
  final bool showNotifications;
  
  /// Callback when notification icon is tapped
  final VoidCallback? onNotificationTap;
  
  /// Whether to show the user avatar
  final bool showUserAvatar;
  
  /// Callback when user avatar is tapped
  final VoidCallback? onAvatarTap;
  
  /// Optional user avatar URL (if not provided, will fetch from profile)
  final String? avatarUrl;
  
  /// Optional user name for avatar fallback (if not provided, will fetch from profile)
  final String? userName;

  const ReusableAppBar({
    super.key,
    required this.title,
    this.scaffoldKey,
    this.actions,
    this.centerTitle = false,
    this.backgroundColor,
    this.textColor,
    this.onLeadingIconPressed,
    this.showBackButton = false,
    this.showLanguageSwitcher = false,
    this.showNotifications = false,
    this.onNotificationTap,
    this.showUserAvatar = false,
    this.onAvatarTap,
    this.avatarUrl,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    // Determine what leading icon/button to show
    IconData? leadingIcon;
    VoidCallback? leadingCallback;

    if (onLeadingIconPressed != null) {
      // Custom callback provided, use it
      leadingCallback = onLeadingIconPressed;
      leadingIcon = Icons.arrow_back_ios_rounded; // Default icon
    } else if (scaffoldKey != null) {
      // Scaffold key provided, show drawer icon
      leadingIcon = Icons.menu_rounded;
      leadingCallback = () {
        HapticFeedback.mediumImpact();
        scaffoldKey!.currentState?.openDrawer();
      };
    } else if (showBackButton || _canPop(context)) {
      // Show back button if explicitly requested or if Navigator can pop
      leadingIcon = Icons.arrow_back_ios_rounded;
      leadingCallback = () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
      };
    }

    // Build actions list with built-in features
    final List<Widget> allActions = [];
    
    // Add custom actions first
    if (actions != null) {
      allActions.addAll(actions!);
      if (actions!.isNotEmpty) {
        allActions.add(const SizedBox(width: 8));
      }
    }
    
    // Add notifications icon if enabled
    if (showNotifications) {
      allActions.add(_buildNotificationIcon(context));
      allActions.add(const SizedBox(width: 8));
    }
    
    // Add language switcher if enabled
    if (showLanguageSwitcher) {
      allActions.add(const LanguageSwitcher());
      allActions.add(const SizedBox(width: 8));
    }
    
    // Add user avatar if enabled
    if (showUserAvatar) {
      allActions.add(_buildUserAvatar(context));
    }
    
    // Remove trailing SizedBox if exists
    if (allActions.isNotEmpty && allActions.last is SizedBox) {
      allActions.removeLast();
    }

    return ModernAppHeader(
      title: title,
      leadingIcon: leadingIcon,
      onLeadingIconPressed: leadingCallback,
      actions: allActions.isEmpty ? null : allActions,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      textColor: textColor,
      showBackButton: showBackButton && leadingIcon == null,
    );
  }

  /// Build notification icon with badge
  Widget _buildNotificationIcon(BuildContext context) {
    final notificationService = UserNotificationService();
    
    return StreamBuilder<List<UserNotification>>(
      stream: notificationService.watchNotifications(),
      builder: (context, snapshot) {
        final unreadCount = notificationService.unreadCount;
        
        return Stack(
          clipBehavior: Clip.none,
          children: [
            HeaderActionButton(
              icon: Icons.notifications,
              tooltip: 'Notifications',
              backgroundColor: Colors.white,
              color: AppColors.primaryBlue,
              onPressed: () {
                HapticFeedback.lightImpact();
                onNotificationTap?.call();
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.accentRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Build user avatar
  Widget _buildUserAvatar(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    
    // Use provided avatar URL or fetch from user metadata
    final String? finalAvatarUrl = avatarUrl ?? 
        currentUser?.userMetadata?['avatar_url'] as String?;
    
    // Use provided user name or fetch from user metadata
    final String finalUserName = userName ?? 
        currentUser?.userMetadata?['full_name'] as String? ??
        currentUser?.email?.split('@').first ??
        'User';
    
    final String userInitial = finalUserName.isNotEmpty 
        ? finalUserName[0].toUpperCase() 
        : 'U';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onAvatarTap?.call();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primaryOrange.withOpacity(0.1),
          backgroundImage: finalAvatarUrl != null && finalAvatarUrl.isNotEmpty
              ? NetworkImage(finalAvatarUrl)
              : null,
          child: finalAvatarUrl == null || finalAvatarUrl.isEmpty
              ? Text(
                  userInitial,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  /// Check if the Navigator can pop (go back)
  bool _canPop(BuildContext context) {
    return Navigator.canPop(context);
  }
}

