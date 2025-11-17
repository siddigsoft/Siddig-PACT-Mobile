# Biometric Authentication Quick Reference

## Quick Start

### 1. Check Availability
```dart
final biometricService = BiometricAuthService();
final isAvailable = await biometricService.isBiometricAvailable();
```

### 2. Get Biometric Type
```dart
final biometrics = await biometricService.getAvailableBiometrics();
final typeName = biometricService.getBiometricTypeName(biometrics);
// Returns: "Face ID", "Fingerprint", "Iris", or "Biometric"
```

### 3. Authenticate
```dart
final authenticated = await biometricService.authenticate(
  reason: 'Login to PACT Mobile',
);
```

### 4. Enable Biometric Login
```dart
// First authenticate
final auth = await biometricService.authenticate(
  reason: 'Verify to enable biometric login',
);

if (auth) {
  // Store credentials
  await biometricService.storeCredentials(email, password);
  
  // Enable biometric
  await biometricService.enableBiometric(email);
}
```

### 5. Biometric Login
```dart
final isEnabled = await biometricService.isBiometricEnabled();

if (isEnabled) {
  final authenticated = await biometricService.authenticate(
    reason: 'Login to PACT Mobile',
  );
  
  if (authenticated) {
    final credentials = await biometricService.getStoredCredentials();
    final email = credentials['email'];
    final password = credentials['password'];
    // Use credentials to login
  }
}
```

## Error Handling

```dart
import 'package:local_auth/error_codes.dart' as auth_error;

try {
  final auth = await biometricService.authenticate(
    reason: 'Authenticate',
  );
} on PlatformException catch (e) {
  switch (e.code) {
    case auth_error.notAvailable:
      // Biometric not available on device
      break;
    case auth_error.notEnrolled:
      // No biometric enrolled - guide user to settings
      break;
    case auth_error.lockedOut:
      // Too many failed attempts - temporarily locked
      break;
    case auth_error.permanentlyLockedOut:
      // Permanently locked - use device settings
      break;
    case auth_error.passcodeNotSet:
      // Device passcode not set
      break;
  }
}
```

## Configuration Checklist

### Android
- [x] `USE_BIOMETRIC` permission in AndroidManifest.xml
- [x] `USE_FINGERPRINT` permission (for backward compatibility)
- [x] MainActivity extends FlutterFragmentActivity

### iOS
- [x] `NSFaceIDUsageDescription` in Info.plist
- [x] Description explains why app needs Face ID

### Dependencies
```yaml
dependencies:
  local_auth: ^2.3.0
  flutter_secure_storage: ^9.0.0
```

## Authentication Options

| Option | Default | Description |
|--------|---------|-------------|
| `stickyAuth` | `true` | Prevents dismissal on lifecycle changes |
| `biometricOnly` | `false` | Allow PIN/pattern fallback |
| `useErrorDialogs` | `true` | Show platform error dialogs |
| `sensitiveTransaction` | `false` | For financial transactions |

## Biometric Types

```dart
enum BiometricType {
  face,         // Face ID / Face Recognition
  fingerprint,  // Touch ID / Fingerprint
  iris,        // Iris scanning (limited devices)
  weak,        // Weak biometric (Android)
  strong,      // Strong biometric (Android)
}
```

## Common Patterns

### Login with Biometric Button
```dart
if (_isBiometricAvailable && _isBiometricEnabled)
  ElevatedButton.icon(
    onPressed: _attemptBiometricLogin,
    icon: Icon(_biometricType.contains('Face') 
      ? Icons.face 
      : Icons.fingerprint),
    label: Text('Login with $_biometricType'),
  )
```

### Biometric Setup Dialog
```dart
if (_isBiometricAvailable && !_isBiometricEnabled) {
  await showDialog(
    context: context,
    builder: (context) => BiometricSetupDialog(
      email: email,
      password: password,
      biometricType: biometricType,
    ),
  );
}
```

### Settings Toggle
```dart
SwitchListTile(
  title: Text('Enable $_biometricType Login'),
  value: _isBiometricEnabled,
  onChanged: (value) async {
    if (value) {
      await _enableBiometric();
    } else {
      await _disableBiometric();
    }
  },
)
```

## Testing

### iOS Simulator
1. Open Features > Face ID
2. Select "Enrolled"
3. Test authentication with "Matching Face"

### Android Emulator
1. Open Settings > Security
2. Add Fingerprint
3. Use emulator controls to simulate touch

## Security Notes

1. **Never store raw passwords** - Use flutter_secure_storage
2. **Always re-authenticate** before enabling biometric
3. **Provide PIN/pattern fallback** - Set biometricOnly: false
4. **Clear credentials on logout** - Call clearStoredCredentials()
5. **Handle all error codes** - Guide users appropriately

## File Locations

- **Service**: `lib/services/biometric_auth_service.dart`
- **Setup Dialog**: `lib/widgets/biometric_setup_dialog.dart`
- **Login Integration**: `lib/authentication/login_screen.dart`
- **Example**: `lib/examples/biometric_auth_example.dart`
- **Tests**: `test/services/biometric_auth_service_test.dart`
- **Documentation**: `BIOMETRIC_AUTHENTICATION_GUIDE.md`

## Support

- **iOS**: ✅ Face ID, Touch ID
- **Android**: ✅ Fingerprint, Face Recognition
- **Web**: ❌ Not supported
- **macOS**: ⚠️ Touch ID (macOS 10.12.2+)
- **Windows**: ⚠️ Windows Hello

## Useful Commands

```bash
# Run tests
flutter test test/services/biometric_auth_service_test.dart

# Build for Android
flutter build apk --release

# Build for iOS
flutter build ios --release

# Run on device
flutter run
```
