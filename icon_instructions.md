# App Icon and Favicon Update Instructions

## Overview

This document provides instructions for updating the app icon and favicon using the `pact_consultancy_pact_cover.jpg` image.

## Android App Icon

1. **Generate Android Icons**:
   - Use Flutter's `flutter_launcher_icons` package:
     - Add to your `pubspec.yaml`:
     ```yaml
     dev_dependencies:
       flutter_launcher_icons: ^0.13.1
     
     flutter_launcher_icons:
       android: true
       ios: true
       image_path: "assets/images/pact_consultancy_pact_cover.jpg"
       adaptive_icon_background: "#FFFFFF"
       adaptive_icon_foreground: "assets/images/pact_consultancy_pact_cover.jpg"
       min_sdk_android: 21
     ```
   - Run the icon generator:
     ```
     flutter pub get
     flutter pub run flutter_launcher_icons
     ```

## iOS App Icon

1. The `flutter_launcher_icons` package will also handle iOS icons.

## Web Favicon

1. **Generate Web Favicon**:
   - Use an online tool like [favicon.io](https://favicon.io) to convert the `pact_consultancy_pact_cover.jpg` to favicon formats
   - Replace the existing favicon files in the `web/` directory:
     - Replace `web/favicon.png`
     - Update the favicon reference in `web/index.html`

## Windows, macOS, and Linux

1. **For other platforms**:
   - The `flutter_launcher_icons` package can be configured to support these platforms as well.
   - Add appropriate settings to the `flutter_launcher_icons` section in `pubspec.yaml`:
   ```yaml
   flutter_launcher_icons:
     # Add to existing configuration
     windows:
       generate: true
       image_path: "assets/images/pact_consultancy_pact_cover.jpg"
     macos:
       generate: true
       image_path: "assets/images/pact_consultancy_pact_cover.jpg"
     linux:
       generate: true
       image_path: "assets/images/pact_consultancy_pact_cover.jpg"
   ```

## Step by Step Implementation

1. Add the `flutter_launcher_icons` package to `pubspec.yaml`
2. Run `flutter pub get`
3. Run `flutter pub run flutter_launcher_icons`
4. For web, update the favicon.png and references in index.html
5. Build and test the app on each platform to verify the icon changes
