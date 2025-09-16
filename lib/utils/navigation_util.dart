// lib/utils/navigation_util.dart
// This file is kept as a stub for backward compatibility
// All navigation is now handled directly in screens using standard Flutter navigation

import 'package:flutter/material.dart';

/// This class is deprecated. Use standard Flutter navigation instead.
///
/// Example:
/// Instead of NavigationUtil.navigateTo(context, '/route')
/// Use Navigator.of(context).pushNamed('/route')
@deprecated
class NavigationUtil {
  /// Navigate to a named route with context - DEPRECATED
  /// Use Navigator.of(context).pushNamed(routeName) instead
  static Future<T?> navigateTo<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    debugPrint(
      '⚠️ NavigationUtil is deprecated. Use standard navigation instead.',
    );
    return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
  }

  /// Navigate to a named route using global navigator key - DEPRECATED
  /// Use Navigator.of(context).pushNamed(routeName) instead
  static Future<T?> globalNavigateTo<T>(String routeName, {Object? arguments}) {
    debugPrint(
      '⚠️ NavigationUtil is deprecated. Use standard navigation instead.',
    );
    return Future.value(null);
  }

  /// Navigate to a named route and replace the current route - DEPRECATED
  /// Use Navigator.of(context).pushReplacementNamed(routeName) instead
  static Future<T?> navigateToAndReplace<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    debugPrint(
      '⚠️ NavigationUtil is deprecated. Use standard navigation instead.',
    );
    return Navigator.of(
      context,
    ).pushReplacementNamed<T, dynamic>(routeName, arguments: arguments);
  }

  /// Navigate to a named route and replace with global navigator - DEPRECATED
  /// Use Navigator.of(context).pushReplacementNamed(routeName) instead
  static Future<T?> globalNavigateToAndReplace<T>(
    String routeName, {
    Object? arguments,
  }) {
    debugPrint(
      '⚠️ NavigationUtil is deprecated. Use standard navigation instead.',
    );
    return Future.value(null);
  }

  /// Navigate to a named route and clear all previous routes - DEPRECATED
  /// Use Navigator.of(context).pushNamedAndRemoveUntil(routeName, (_) => false) instead
  static Future<T?> navigateAndRemoveUntil<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    debugPrint(
      '⚠️ NavigationUtil is deprecated. Use standard navigation instead.',
    );
    return Navigator.of(
      context,
    ).pushNamedAndRemoveUntil<T>(routeName, (_) => false, arguments: arguments);
  }

  /// Pop the current route and return to previous screen - DEPRECATED
  /// Use Navigator.of(context).pop() instead
  static void goBack<T>(BuildContext context, [T? result]) {
    debugPrint(
      '⚠️ NavigationUtil is deprecated. Use standard navigation instead.',
    );
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop<T>(result);
    }
  }
}
