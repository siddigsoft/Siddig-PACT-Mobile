# Android Biometric Authentication Configuration

## Overview

This guide covers all the Android-specific configurations required for biometric authentication to work properly, following the official `local_auth` package documentation.

## ✅ Configuration Checklist

### 1. AndroidManifest.xml - Permissions

**Location:** `android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- REQUIRED: Biometric authentication permissions -->
    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
    <uses-permission android:name="android.permission.USE_FINGERPRINT"/>
    
    <!-- Other app permissions... -->
</manifest>
```

**Status:** ✅ **CONFIGURED** - Both permissions present in your manifest

---

### 2. MainActivity - FragmentActivity Requirement

**Location:** `android/app/src/main/kotlin/.../MainActivity.kt`

The `local_auth` plugin **requires** `FlutterFragmentActivity` instead of `FlutterActivity`.

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
    // Your code here
}
```

**Why?** The biometric authentication dialog requires Fragment support to display properly.

**Status:** ✅ **CONFIGURED** - MainActivity extends FlutterFragmentActivity

---

### 3. Theme Configuration - AppCompat Theme

**Location:** `android/app/src/main/res/values/styles.xml`

**CRITICAL:** Your app theme **must** inherit from `Theme.AppCompat` to prevent crashes on Android 8 and below.

```xml
<resources>
    <style name="LaunchTheme" parent="Theme.AppCompat.DayNight">
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="windowActionBar">false</item>
        <item name="windowNoTitle">true</item>
    </style>
    
    <style name="NormalTheme" parent="Theme.AppCompat.DayNight">
        <item name="android:windowBackground">?android:colorBackground</item>
        <item name="windowActionBar">false</item>
        <item name="windowNoTitle">true</item>
    </style>
</resources>
```

**Key Points:**
- ✅ Parent must be `Theme.AppCompat.DayNight` (or any AppCompat theme)
- ✅ `Theme.AppCompat.DayNight` enables automatic light/dark mode support
- ✅ Use `windowActionBar` and `windowNoTitle` items to hide the action bar

**Status:** ✅ **FIXED** - Updated from `@android:style/Theme.Light.NoTitleBar` to `Theme.AppCompat.DayNight`

---

### 4. Night Theme Configuration

**Location:** `android/app/src/main/res/values-night/styles.xml`

```xml
<resources>
    <style name="LaunchTheme" parent="Theme.AppCompat.DayNight">
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="windowActionBar">false</item>
        <item name="windowNoTitle">true</item>
    </style>
    
    <style name="NormalTheme" parent="Theme.AppCompat.DayNight">
        <item name="android:windowBackground">?android:colorBackground</item>
        <item name="windowActionBar">false</item>
        <item name="windowNoTitle">true</item>
    </style>
</resources>
```

**Status:** ✅ **FIXED** - Updated from `@android:style/Theme.Black.NoTitleBar` to `Theme.AppCompat.DayNight`

---

### 5. Alternative: AndroidManifest.xml Theme Configuration

If you don't have `styles.xml` files, you can set the theme directly in `AndroidManifest.xml`:

```xml
<application
    android:label="your_app_name"
    android:icon="@mipmap/ic_launcher">
    <activity
        android:name=".MainActivity"
        android:theme="@style/Theme.AppCompat.DayNight"
        android:exported="true"
        ...>
    </activity>
</application>
```

**Status:** ℹ️ Using styles.xml approach (recommended)

---

## Platform-Specific Considerations

### Android API Level Support

#### API 29+ (Android 10+)
- ✅ Full biometric support (Face, Fingerprint, Iris)
- ✅ Can check specific biometric types with `getAvailableBiometrics()`
- ✅ Strong/Weak biometric classification available

#### API 28 and below (Android 9 and earlier)
- ⚠️ **Limited biometric type detection**
- ⚠️ Can only check for fingerprint hardware
- 💡 **Solution:** Use `authenticate(biometricOnly: true)` instead of checking types
- 💡 This returns an error if no biometric hardware exists

**Example for Android 8 support:**
```dart
// DON'T do this on Android < 29
final biometrics = await auth.getAvailableBiometrics();
if (biometrics.contains(BiometricType.face)) {
  // This won't work reliably on Android < 29
}

// DO this instead
try {
  final result = await auth.authenticate(
    localizedReason: 'Please authenticate',
    biometricOnly: true, // Returns error if no biometric available
  );
} catch (e) {
  // Handle no biometric hardware
}
```

---

## Biometric Types on Android

### Available BiometricType Values

1. **BiometricType.fingerprint**
   - Traditional fingerprint sensor
   - Most common on older devices

2. **BiometricType.face**
   - Face recognition
   - Available on newer Android devices

3. **BiometricType.strong**
   - Strong biometric (Class 3)
   - High security level
   - Includes secure fingerprint and iris

4. **BiometricType.weak**
   - Weak biometric (Class 2)
   - Lower security level
   - May include some face recognition implementations

5. **BiometricType.iris**
   - Iris scanning
   - Rare on consumer devices

---

## Dialog Customization

### Android-Specific Messages

You can customize the biometric dialog on Android:

```dart
import 'package:local_auth_android/local_auth_android.dart';

await auth.authenticate(
  localizedReason: 'Authenticate to access your account',
  authMessages: const [
    AndroidAuthMessages(
      signInTitle: 'Biometric Login',
      cancelButton: 'Cancel',
      biometricHint: 'Verify your identity',
      biometricNotRecognized: 'Not recognized. Try again.',
      biometricSuccess: 'Authentication successful',
      deviceCredentialsRequiredTitle: 'Device Credential Required',
      deviceCredentialsSetupDescription: 'Please set up device credentials',
      goToSettingsButton: 'Go to Settings',
      goToSettingsDescription: 'Biometric authentication is not set up.',
    ),
  ],
);
```

**Status:** ✅ **IMPLEMENTED** in BiometricAuthService

---

## Testing Checklist

### Device Testing

Test on actual Android devices with:

- [ ] **Android 8 (API 26)** - Fingerprint only
- [ ] **Android 9 (API 28)** - Fingerprint, basic face
- [ ] **Android 10+ (API 29+)** - Full biometric support
- [ ] Device with **fingerprint** sensor
- [ ] Device with **face recognition**
- [ ] Device with **no biometrics** (test fallback)

### Test Scenarios

1. **Successful Authentication**
   ```dart
   final success = await biometricService.authenticate();
   // Should return true on successful auth
   ```

2. **No Biometrics Enrolled**
   ```dart
   // User has no fingerprints/face registered
   // Should show appropriate error message
   ```

3. **Hardware Not Available**
   ```dart
   final available = await biometricService.isBiometricAvailable();
   // Should return false on devices without biometric hardware
   ```

4. **Biometric Only Mode**
   ```dart
   final success = await biometricService.authenticateBiometricOnly();
   // Should not show PIN/pattern fallback
   ```

5. **Multiple Failed Attempts**
   ```dart
   // Test lockout scenarios
   // Should handle lockedOut and permanentlyLockedOut errors
   ```

6. **App Backgrounding**
   ```dart
   final success = await biometricService.authenticateWithBackgroundHandling();
   // Should wait for app to return to foreground
   ```

---

## Common Issues and Solutions

### Issue 1: "FlutterFragmentActivity not found"
**Solution:** Ensure MainActivity extends `FlutterFragmentActivity` not `FlutterActivity`

### Issue 2: App crashes on Android 8
**Solution:** Change theme parent from `@android:style/Theme.*` to `Theme.AppCompat.DayNight`

### Issue 3: Biometric dialog doesn't appear
**Solution:** 
- Check `USE_BIOMETRIC` permission in manifest
- Verify MainActivity extends `FlutterFragmentActivity`
- Ensure device has biometrics enrolled

### Issue 4: "No implementation found for method authenticate"
**Solution:** Run `flutter clean && flutter pub get`

### Issue 5: Theme.AppCompat not found
**Solution:** AppCompat is included by default in Flutter. If missing:
```gradle
// In android/app/build.gradle.kts
dependencies {
    implementation("androidx.appcompat:appcompat:1.6.1")
}
```

---

## Build Configuration

### Minimum SDK Version

Ensure your `android/app/build.gradle.kts` has:

```kotlin
android {
    defaultConfig {
        minSdk = 21  // Minimum for biometric support
        targetSdk = 35
    }
}
```

**Status:** ℹ️ Check your build.gradle.kts file

---

## Security Best Practices

1. **Always check availability first**
   ```dart
   if (await biometricService.isBiometricAvailable()) {
     await biometricService.authenticate();
   }
   ```

2. **Check for enrolled biometrics**
   ```dart
   if (await biometricService.hasEnrolledBiometrics()) {
     // Biometrics are set up
   }
   ```

3. **Handle all error cases**
   ```dart
   try {
     await auth.authenticate(...);
   } on PlatformException catch (e) {
     // Handle specific error codes
   }
   ```

4. **Use biometricOnly for sensitive operations**
   ```dart
   // For payments, sensitive data access
   await auth.authenticate(biometricOnly: true);
   ```

5. **Store sensitive data securely**
   ```dart
   // Use flutter_secure_storage with biometric protection
   await secureStorage.write(key: 'token', value: token);
   ```

---

## Summary

✅ **All Required Android Configurations Complete:**

1. ✅ Permissions added to AndroidManifest.xml
2. ✅ MainActivity extends FlutterFragmentActivity  
3. ✅ Theme updated to Theme.AppCompat.DayNight
4. ✅ Night theme configured
5. ✅ Platform-specific auth messages implemented
6. ✅ All biometric types supported
7. ✅ Error handling for all scenarios
8. ✅ Comprehensive BiometricAuthService implementation

Your app is now fully configured for Android biometric authentication! 🎉

---

## Next Steps

1. Run `flutter pub get` to fetch new dependencies
2. Test on physical Android devices
3. Review `BIOMETRIC_QUICK_REFERENCE.md` for usage examples
4. Check `lib/examples/biometric_auth_example.dart` for complete implementation

