# Quick Android Notification Setup

## Add Permissions to AndroidManifest.xml

Location: `android/app/src/main/AndroidManifest.xml`

Add this inside the `<manifest>` tag (before `<application>`):

```xml
<!-- Notification permission for Android 13+ -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

## Test the Notifications

### Test Chat Notification (Manually)
```dart
import 'package:pact_mobile/services/notification_service.dart';

// In any widget or screen:
await NotificationService.showChatMessageNotification(
  senderName: 'Test User',
  message: 'This is a test message!',
  chatId: 'test-123',
);
```

### Test MMP Notification (Manually)
```dart
await NotificationService.showMMPFileNotification(
  title: 'New MMP File Available',
  body: 'Test User uploaded: Test Document.pdf',
  fileId: 'test-456',
  fileName: 'Test Document.pdf',
);
```

### Test Update Notification (Manually)
```dart
import 'package:pact_mobile/services/update_service.dart';

// Check for updates
await UpdateService().checkForUpdatesOnStartup();
```

## Automatic Testing

### Chat Notifications (Real-time)
1. Login on two different devices/accounts
2. Send a message from Device A
3. Device B should receive a notification immediately

### MMP File Notifications (Real-time)
1. Login on two different devices/accounts
2. Upload an MMP file from Device A
3. Device B should receive a notification immediately

### Update Notifications (Shorebird)
1. Release a Shorebird patch:
   ```bash
   shorebird patch android
   ```
2. Open the app
3. Should see update notification if patch available

## Troubleshooting

### If notifications don't appear:

1. Check permissions are granted:
   ```dart
   await Permission.notification.request();
   ```

2. Check if notification service is initialized:
   ```dart
   await NotificationService.initialize();
   ```

3. Check Android notification settings:
   - Go to Settings > Apps > PACT Mobile > Notifications
   - Ensure notifications are enabled

4. Check logs for errors:
   ```bash
   flutter logs
   ```

## Done! 🎉

Your notification system is now set up and ready to use!
