# Biometric Authentication Implementation Guide

## Overview
This app uses the `local_auth` package (v2.3.0) to provide biometric authentication capabilities including Face ID, Touch ID, and fingerprint authentication across iOS and Android platforms.

## Platform Configuration

### Android Configuration

#### 1. AndroidManifest.xml Permissions
The following permissions are already configured in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
```

**Note**: `USE_FINGERPRINT` is deprecated but included for backward compatibility with older Android versions.

#### 2. MainActivity Configuration
The `MainActivity.kt` is properly configured with `FlutterFragmentActivity` which is required for biometric authentication:

```kotlin
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }
}
```

### iOS Configuration

#### Info.plist Configuration
The following key is configured in `ios/Runner/Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>We use Face ID to let you sign in securely without your password.</string>
```

This description is shown to users when requesting Face ID permission.

## Service Implementation

### BiometricAuthService
Location: `lib/services/biometric_auth_service.dart`

The service provides the following methods:

#### 1. Check Biometric Availability
```dart
Future<bool> isBiometricAvailable()
```
Checks if the device supports biometric authentication (Face ID, Touch ID, or fingerprint).

#### 2. Get Available Biometrics
```dart
Future<List<BiometricType>> getAvailableBiometrics()
```
Returns the types of biometric authentication available on the device:
- `BiometricType.face` - Face ID (iOS) or Face Recognition (Android)
- `BiometricType.fingerprint` - Touch ID (iOS) or Fingerprint (Android)
- `BiometricType.iris` - Iris scanning (limited Android devices)

#### 3. Get Friendly Biometric Name
```dart
String getBiometricTypeName(List<BiometricType> biometrics)
```
Converts biometric types to user-friendly names (e.g., "Face ID", "Fingerprint").

#### 4. Authenticate User
```dart
Future<bool> authenticate({String reason})
```
Performs biometric authentication with the following options:
- `stickyAuth: true` - Prevents auth dialog from dismissing on app lifecycle changes
- `biometricOnly: false` - Allows fallback to device PIN/pattern/password
- `useErrorDialogs: true` - Shows platform-specific error dialogs
- `sensitiveTransaction: false` - Standard authentication (not a financial transaction)

**Error Handling**: The method properly handles these error codes:
- `notAvailable` - Biometric hardware not available
- `notEnrolled` - No biometric credentials enrolled
- `lockedOut` - Too many failed attempts (temporary lock)
- `permanentlyLockedOut` - Permanently locked out
- `passcodeNotSet` - Device passcode not configured

#### 5. Enable/Disable Biometric Login
```dart
Future<void> enableBiometric(String userEmail)
Future<void> disableBiometric()
```
Manages biometric login preferences and stores encrypted user email.

#### 6. Credential Management
```dart
Future<void> storeCredentials(String email, String password)
Future<Map<String, String?>> getStoredCredentials()
Future<void> clearStoredCredentials()
```
Securely stores and retrieves user credentials using Flutter Secure Storage.

## UI Components

### 1. BiometricSetupDialog
Location: `lib/widgets/biometric_setup_dialog.dart`

A dialog shown after successful login that offers to enable biometric authentication. Features:
- Modern UI with gradient design
- Animated icon based on biometric type
- Clear explanation of biometric benefits
- "Enable" and "Maybe Later" options

### 2. Login Screen Integration
Location: `lib/authentication/login_screen.dart`

The login screen includes:
- Automatic biometric availability check on initialization
- Auto-prompt for biometric login if enabled
- Visible biometric login button when available
- Seamless credential retrieval from secure storage

## Usage Example

### Basic Authentication Flow

```dart
// Check if biometric is available
final isAvailable = await biometricService.isBiometricAvailable();

if (isAvailable) {
  // Get available biometric types
  final biometrics = await biometricService.getAvailableBiometrics();
  final typeName = biometricService.getBiometricTypeName(biometrics);
  
  // Authenticate
  final authenticated = await biometricService.authenticate(
    reason: 'Login to PACT Mobile',
  );
  
  if (authenticated) {
    // Proceed with secure operation
    final credentials = await biometricService.getStoredCredentials();
    // Use credentials for login
  }
}
```

### Error Handling Example

```dart
try {
  final authenticated = await biometricService.authenticate(
    reason: 'Verify your identity',
  );
  
  if (authenticated) {
    // Success - proceed
  }
} on PlatformException catch (e) {
  if (e.code == auth_error.notEnrolled) {
    // Guide user to enroll biometric in settings
  } else if (e.code == auth_error.lockedOut) {
    // Show temporary lockout message
  }
  // Handle other error codes...
}
```

## Security Considerations

1. **Credential Storage**: User credentials are stored using `flutter_secure_storage` which provides:
   - AES encryption on Android
   - Keychain storage on iOS

2. **Biometric Authentication Options**:
   - `biometricOnly: false` allows device credential fallback, improving accessibility
   - `sensitiveTransaction: false` for standard login (use `true` for financial transactions)
   - `useErrorDialogs: true` provides clear user feedback

3. **Best Practices**:
   - Always verify biometric authentication before storing credentials
   - Clear credentials when biometric is disabled
   - Handle all error codes gracefully
   - Provide alternative login methods

## Testing

### iOS Testing
- **Simulator**: Go to Features > Face ID > Enrolled to test Face ID
- **Device**: Requires actual device with Face ID or Touch ID

### Android Testing
- **Emulator**: Configure fingerprint in emulator settings
- **Device**: Requires actual device with fingerprint sensor

## Common Error Codes

| Error Code | Description | User Action |
|------------|-------------|-------------|
| `notAvailable` | Biometric hardware not available | Use password login |
| `notEnrolled` | No biometric credentials enrolled | Set up in device settings |
| `lockedOut` | Too many failed attempts | Wait or use device credential |
| `permanentlyLockedOut` | Permanently locked | Use device settings to unlock |
| `passcodeNotSet` | Device passcode not configured | Set up device passcode |

## Dependencies

```yaml
dependencies:
  local_auth: ^2.3.0
  flutter_secure_storage: ^9.0.0
```

## Platform Support

- ✅ **iOS**: Face ID, Touch ID
- ✅ **Android**: Fingerprint, Face Recognition
- ❌ **Web**: Not supported (web browsers have their own biometric APIs)
- ⚠️ **macOS**: Supported but requires macOS 10.12.2+
- ⚠️ **Windows**: Supported with Windows Hello

## Additional Resources

- [local_auth Package Documentation](https://pub.dev/packages/local_auth)
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)
- [Android Biometric API Guide](https://developer.android.com/training/sign-in/biometric-auth)
- [iOS LocalAuthentication Guide](https://developer.apple.com/documentation/localauthentication)

## Troubleshooting

### Issue: Biometric authentication not working on Android
**Solution**: Ensure `MainActivity` extends `FlutterFragmentActivity` and permissions are in `AndroidManifest.xml`

### Issue: Face ID not prompting on iOS
**Solution**: Check that `NSFaceIDUsageDescription` is in `Info.plist` with a valid description

### Issue: Biometric authentication fails on simulator
**Solution**: Ensure biometric enrollment is configured in simulator/emulator settings

### Issue: Credentials not persisting
**Solution**: Check that Flutter Secure Storage is properly initialized and device has secure storage available
