# Background Notifications Fix for Android

## Problem Summary
Users were not receiving notifications when the app was not open on Android devices. This is due to:
1. Missing notification permission on Android 13+
2. Missing foreground service configuration for background notification handling
3. App service lifecycle not properly configured for background processing

## Solutions Implemented

### 1. AndroidManifest.xml Changes
✅ **Added POST_NOTIFICATIONS permission** - Required for Android 13+ to show notifications
✅ **Added FOREGROUND_SERVICE_DATA_SYNC** - Allows background synchronization with notification capability

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
```

### 2. Dart Code Updates
✅ **NotificationService.initialize()** - Now requests runtime notification permission
- Checks Android OS version
- Requests POST_NOTIFICATIONS permission
- Handles permission states (granted, denied, permanently denied)
- Opens app settings if permission permanently denied

### 3. BiometricAuthService Improvements
✅ **Enhanced error handling** for Android biometric failures
✅ **Fixed device credential support** - Falls back to device PIN/pattern if biometric fails
✅ **Improved platform-specific dialogs** with better error messages
✅ **Added proper exception handling** for all biometric edge cases

## Testing Checklist

### Before Testing
- [ ] Clean build: `flutter clean && flutter pub get`
- [ ] Build APK: `flutter build apk --release`
- [ ] Or build bundle: `flutter build appbundle`

### Testing Notifications
1. **Grant Permission When Prompted**
   - [ ] Allow notification permission when app first opens
   - [ ] If denied, manually enable in Settings > Apps > [App Name] > Notifications

2. **Test Background Notifications**
   - [ ] Send a notification while app is running
   - [ ] Minimize/close the app (don't force stop)
   - [ ] Send a notification from backend/admin panel
   - [ ] Verify notification appears in system tray
   - [ ] Tap notification - verify app opens/navigates correctly

3. **Test Persistence After App Close**
   - [ ] Close app completely
   - [ ] Trigger a notification from backend
   - [ ] Phone should show notification in system tray
   - [ ] Tap notification to open app

### Testing Biometric Authentication
1. **Device Setup**
   - [ ] Device has fingerprint/face biometric enrolled
   - [ ] Device has PIN/pattern/password set

2. **Test Biometric Login**
   - [ ] Enable biometric during first login
   - [ ] Close app
   - [ ] Reopen app - tap biometric login button
   - [ ] Device should show biometric prompt
   - [ ] Verify successful authentication

3. **Test Fallback to Device Credentials**
   - [ ] Try biometric login
   - [ ] When prompted, tap "Use device PIN" or equivalent
   - [ ] Enter PIN/pattern to verify it works as fallback

4. **Test Error Cases**
   - [ ] Too many failed biometric attempts
   - [ ] Should lock temporarily and suggest trying again
   - [ ] Device with no biometric enrolled
   - [ ] Should show appropriate error message

## Common Issues and Fixes

### Issue: Notifications Still Not Working

**Check 1: Permissions Granted?**
```bash
flutter run
# When prompted, ALLOW notification permission
# Check Settings > Apps > [App Name] > Notifications is ON
```

**Check 2: App Not Force Stopped?**
- Don't use "Force Stop" - just minimize/close
- Background service needs time to listen
- Test on actual device, not emulator if possible

**Check 3: Firebase/Backend Sending Correctly?**
- Verify push notification service is configured
- Check backend is sending to correct device token
- Look for network requests in app logs

### Issue: Biometric Not Working on Android Phone

**Common Causes:**
1. **No biometric enrolled** - Go to Settings > Security > Biometric and add fingerprint/face
2. **Biometric permission not granted** - Check Android manifest has USE_BIOMETRIC and USE_FINGERPRINT
3. **Device credential not set** - Device needs PIN/pattern for fallback
4. **Wrong Intent flags** - Our implementation now includes proper intent configuration
5. **Hardware support** - Some devices have buggy biometric implementations

**Debug Steps:**
```dart
// Add this to login screen to see available biometrics:
final biometrics = await BiometricAuthService().getAvailableBiometrics();
print('Available biometrics: $biometrics');

// Check if enrolled:
final hasEnrolled = await BiometricAuthService().hasEnrolledBiometrics();
print('Has enrolled biometrics: $hasEnrolled');
```

**Advanced Troubleshooting:**
1. Device has biometric hardware but might not expose it to apps
   - Try on different device if possible
   
2. Android version issues (API level)
   - Biometric support varies by Android version
   - Our implementation supports API 21+ with proper fallbacks
   
3. Plugin conflict
   - Try: `flutter pub upgrade local_auth local_auth_android`

## Files Modified
- ✅ `android/app/src/main/AndroidManifest.xml` - Added notification permissions
- ✅ `lib/services/notification_service.dart` - Added runtime permission request
- ✅ `lib/services/biometric_auth_service.dart` - Enhanced error handling

## Next Steps if Still Having Issues
1. Share device logs: `flutter logs`
2. Try test app on emulator with Android 13+ image
3. Clear app data: Settings > Apps > [App Name] > Storage > Clear Data
4. Reinstall app completely

## Code Examples for Manual Testing

### Send Test Notification
```dart
// In your app where you handle login success
await NotificationService.showUserNotification(
  notificationId: 'test_${DateTime.now().millisecondsSinceEpoch}',
  title: 'Test Notification',
  body: 'This is a test from your PACT app',
);
```

### Check Biometric Status
```dart
final bioService = BiometricAuthService();
final available = await bioService.isBiometricAvailable();
final enrolled = await bioService.hasEnrolledBiometrics();
final biometrics = await bioService.getAvailableBiometrics();

print('Biometric Available: $available');
print('Biometric Enrolled: $enrolled');
print('Types: $biometrics');
```

## Performance Notes
- Notification permission request is non-blocking
- Biometric operations include 30-second timeout
- Background notification handler runs independent of UI thread
- No memory leaks - services properly dispose resources

## Security Notes
- Biometric data never stored in app
- Device handles all biometric processing
- Device credentials always required as fallback
- Notifications encrypted in transit via Firebase/backend
