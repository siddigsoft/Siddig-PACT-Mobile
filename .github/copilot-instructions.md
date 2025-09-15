# PACT Mobile App - AI Coding Assistant Guidelines

## Project Overview

PACT Mobile is a Flutter application being developed for PACT Consultancy. The app follows a modern, clean UI design with a focus on user authentication workflows (currently implemented) with plans for additional features.

## Architecture & Structure

- **Main App Configuration**: `lib/main.dart` - Entry point with theme setup and route configuration
- **Authentication Flow**: `lib/authentication/` - Contains login, registration, and password reset screens
- **Theme System**: `lib/theme/` - Centralized color system in `app_colors.dart`
- **Assets Management**: Images stored in `assets/images/`, icons in `assets/icons/`

## Key Patterns & Conventions

### State Management

- Currently using `StatefulWidget` pattern for screen state management
- Animation controllers for UI transitions using `SingleTickerProviderStateMixin` or `TickerProviderStateMixin`

### UI/UX Design

- Modern, clean UI with consistent styling
- Animation patterns using `flutter_animate` package for smooth transitions
  ```dart
  widget.animate()
    .fadeIn(duration: 600.ms, delay: 300.ms)
    .slideY(begin: 0.3, end: 0, duration: 500.ms)
  ```
- Consistent form validation patterns in authentication screens

### Theme System

- Color definitions centralized in `AppColors` class
- Gradient definitions for buttons and backgrounds
- Shadow styles for elevated components
- Example usage:
  ```dart
  Container(
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient,
      borderRadius: BorderRadius.circular(16),
    )
  )
  ```

## Developer Workflows

### Setup & Installation

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Set up emulators/devices for testing
4. Run with `flutter run`

### App Icon Generation

For updating app icons across platforms:
1. Ensure image is placed in `assets/images/`
2. Update icon configuration in `pubspec.yaml` if needed
3. Run: `flutter pub run flutter_launcher_icons`

## Testing

- Basic widget tests in `test/widget_test.dart`
- Run tests with: `flutter test`
- The test suite is under development and not fully implemented

## Future Development

- Currently, authentication UI is implemented but not connected to backend services
- Form validation logic exists but actual API integration is pending
- TODOs in code mark places where backend integration will be needed

## Common Tasks

- **Adding New Screens**: Create screen in appropriate directory, update routes in `main.dart`
- **Styling Elements**: Use the theme styles defined in `main.dart` or color constants from `app_colors.dart`
- **Form Validation**: Follow validation patterns in authentication screens