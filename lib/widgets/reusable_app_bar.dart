// lib/widgets/reusable_app_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'modern_app_header.dart';

/// A reusable AppBar widget that can be used across all pages.
/// 
/// This widget automatically handles:
/// - Displaying the page title
/// - Showing drawer icon if scaffoldKey is provided
/// - Showing back button if Navigator can pop and no drawer is available
/// - Accepting custom actions for additional buttons
/// 
/// Example usage with drawer:
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
///         actions: [
///           HeaderActionButton(...),
///         ],
///       ),
///       // Rest of content
///     ],
///   ),
/// )
/// ```
/// 
/// Example usage with back button (no drawer):
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

    return ModernAppHeader(
      title: title,
      leadingIcon: leadingIcon,
      onLeadingIconPressed: leadingCallback,
      actions: actions,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      textColor: textColor,
      showBackButton: showBackButton && leadingIcon == null,
    );
  }

  /// Check if the Navigator can pop (go back)
  bool _canPop(BuildContext context) {
    return Navigator.canPop(context);
  }
}

