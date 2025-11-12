# 📱 PACT Mobile Notification System

## Overview
This document describes the comprehensive notification system implemented for PACT Mobile, including support for:
1. **Shorebird OTA Updates** - Notify users when app updates are available
2. **Chat Messages** - Real-time notifications for new messages
3. **MMP File Uploads** - Notifications when new MMP files are uploaded

## 🔔 Features Implemented

### 1. Enhanced Notification Service (`lib/services/notification_service.dart`)

A comprehensive notification service with three specialized channels:

#### Chat Message Notifications
- **Channel ID**: `chat_messages`
- **Features**:
  - Shows sender name and message preview
  - Plays sound and vibration
  - Tappable - navigates to specific chat
  - Badge updates
  - Big text style for long messages

#### MMP File Notifications
- **Channel ID**: `mmp_files`
- **Features**:
  - Shows uploader name and file details
  - High priority notifications
  - Tappable - navigates to file details
  - Custom notification sound

#### App Update Notifications
- **Channel ID**: `app_updates`
- **Features**:
  - Shows when Shorebird updates are available
  - Three states:
    - Update available
    - Download in progress
    - Update installed
  - Tappable - triggers update installation
  - Progress indicator during download

### 2. Update Service (`lib/services/update_service.dart`)

Manages Shorebird OTA updates with automatic detection:

```dart
// Features:
- checkForUpdatesOnStartup() - Check on app launch
- downloadAndInstallUpdate() - Install patches
- startPeriodicUpdateCheck() - Check every 30 minutes
- getCurrentPatchNumber() - Get version info
```

**How it works:**
1. App checks for updates on startup
2. If update found, shows notification
3. User taps notification → Update dialog appears
4. User confirms → Download & install
5. Success notification → Restart prompt

### 3. Realtime Notification Service (`lib/services/realtime_notification_service.dart`)

Listens to Supabase real-time events for instant notifications:

#### Chat Message Listener
```dart
// Subscribes to: public.chat_messages table
// Triggers on: INSERT events
// Filters out: Own messages
// Shows: Sender name + message content
```

#### MMP File Listener
```dart
// Subscribes to: public.reports table
// Triggers on: INSERT events
// Filters out: Own uploads
// Shows: Uploader name + file title
```

### 4. Update Dialog Widget (`lib/widgets/update_dialog.dart`)

Beautiful UI for managing updates:
- Modern gradient design
- Progress indicator
- Two-button interface (Later / Update Now)
- Shows version information
- Visual feedback during installation

## 🚀 Setup Instructions

### Step 1: Install Dependencies

Already added to `pubspec.yaml`:
```yaml
dependencies:
  flutter_local_notifications: ^19.4.2
  shorebird_code_push: ^1.1.0
  firebase_messaging: ^15.1.6  # Optional for FCM
```

Run:
```bash
flutter pub get
```

### Step 2: Android Configuration

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
  <application>
    <!-- Inside <application> tag -->
    
    <!-- Notification permission (Android 13+) -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    
    <!-- Notification icon -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_icon"
        android:resource="@mipmap/ic_launcher" />
        
    <!-- Notification color -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_color"
        android:resource="@color/notification_color" />
        
    <!-- Notification channels -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_channel_id"
        android:value="default_channel" />
  </application>
</manifest>
```

### Step 3: iOS Configuration

Add to `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

Request permissions in code (already implemented in notification_service.dart).

### Step 4: Initialize Services

Already configured in `lib/main.dart`:

```dart
void main() async {
  // ... other initialization
  
  // Initialize notification service
  await NotificationService.initialize(
    onNotificationTap: (response) {
      final payload = response.payload;
      if (payload != null) {
        if (payload.startsWith('chat:')) {
          // Navigate to chat
        } else if (payload.startsWith('mmp:')) {
          // Navigate to MMP file
        } else if (payload.startsWith('update:')) {
          // Trigger update
        }
      }
    },
  );
  
  // Check for updates
  final updateService = UpdateService();
  await updateService.checkForUpdatesOnStartup();
  updateService.startPeriodicUpdateCheck();
  
  runApp(MyApp());
}
```

### Step 5: Initialize After Login

Already configured in `lib/authentication/login_screen.dart`:

```dart
// After successful login
await RealtimeNotificationService().initialize();
Navigator.pushReplacementNamed(context, '/main');
```

## 📋 Usage Examples

### Manually Trigger Chat Notification

```dart
await NotificationService.showChatMessageNotification(
  senderName: 'John Doe',
  message: 'Hey, how are you?',
  chatId: 'chat-123',
);
```

### Manually Trigger MMP Notification

```dart
await NotificationService.showMMPFileNotification(
  title: 'New MMP File Available',
  body: 'Francis uploaded: Monthly Report.pdf',
  fileId: 'file-456',
  fileName: 'Monthly Report.pdf',
);
```

### Manually Check for Updates

```dart
final updateService = UpdateService();
await updateService.checkForUpdatesOnStartup();
```

### Show Update Dialog

```dart
await UpdateDialog.show(context, 'v1.2.3');
```

## 🔄 Automatic Behaviors

### Chat Notifications
- ✅ **Automatic**: Triggered when new message inserted in `chat_messages` table
- ✅ **Filtered**: Won't show for your own messages
- ✅ **Real-time**: Uses Supabase real-time subscriptions
- ✅ **Navigation**: Tap notification → Opens specific chat

### MMP File Notifications
- ✅ **Automatic**: Triggered when new file inserted in `reports` table
- ✅ **Filtered**: Won't show for your own uploads
- ✅ **Real-time**: Uses Supabase real-time subscriptions
- ✅ **Navigation**: Tap notification → Opens file details

### Update Notifications
- ✅ **Automatic**: Checked on app startup
- ✅ **Periodic**: Rechecks every 30 minutes
- ✅ **Silent**: Background check, only shows if update found
- ✅ **One-tap**: Tap notification → Install immediately

## 🎨 Notification Appearance

### Chat Message
```
┌─────────────────────────────┐
│ 📱 John Doe                 │
│ Hey, how are you doing?     │
│ Just now                     │
└─────────────────────────────┘
```

### MMP File
```
┌─────────────────────────────┐
│ 📁 New MMP File Available   │
│ Francis uploaded:            │
│ Monthly Report October.pdf   │
└─────────────────────────────┘
```

### App Update
```
┌─────────────────────────────┐
│ 🎉 App Update Available     │
│ A new version (Patch 5) is  │
│ ready to install. Tap to    │
│ update now!                  │
└─────────────────────────────┘
```

## 🔧 Troubleshooting

### Notifications Not Showing

1. **Check permissions**:
```dart
// Android 13+ requires runtime permission
await Permission.notification.request();
```

2. **Check initialization**:
```dart
// Make sure initialize() was called
await NotificationService.initialize();
```

3. **Check platform support**:
- Local notifications work on Android & iOS
- Web has limited support (browser notifications)
- Shorebird only works on mobile (Android/iOS)

### Updates Not Detected

1. **Verify Shorebird setup**:
```bash
# Check if shorebird.yaml exists
cat shorebird.yaml

# Verify app_id is set
grep "app_id" shorebird.yaml
```

2. **Check if patch available**:
```bash
# Release a patch first
shorebird patch android
shorebird patch ios
```

3. **Test manually**:
```dart
final updateService = UpdateService();
final patchNumber = await updateService.getCurrentPatchNumber();
print('Current patch: $patchNumber');
```

### Real-time Not Working

1. **Check Supabase connection**:
```dart
final status = Supabase.instance.client.realtime.channels;
print('Channels: $status');
```

2. **Verify table permissions**:
- Ensure RLS policies allow SELECT on `chat_messages`
- Ensure RLS policies allow SELECT on `reports`

3. **Check user authentication**:
```dart
final user = Supabase.instance.client.auth.currentUser;
print('User: ${user?.id}');
```

## 📊 Testing Checklist

### Chat Notifications
- [ ] Send message from another user
- [ ] Verify notification appears
- [ ] Tap notification → Opens chat
- [ ] Own messages don't trigger notification

### MMP File Notifications
- [ ] Upload MMP file from another account
- [ ] Verify notification appears
- [ ] Tap notification → Opens file details
- [ ] Own uploads don't trigger notification

### Update Notifications
- [ ] Release Shorebird patch
- [ ] Restart app
- [ ] Verify update notification appears
- [ ] Tap notification → Update dialog opens
- [ ] Complete update → Success message

## 🚧 Known Limitations

1. **Web Platform**: 
   - Shorebird OTA updates not supported on web
   - Local notifications have limited functionality
   - Real-time subscriptions work but notifications may not show

2. **Background Updates**:
   - Shorebird downloads patches in background
   - But app needs to be opened for check to occur
   - Consider implementing WorkManager for true background checks

3. **Notification Customization**:
   - Sounds use default system sounds
   - Custom sounds require additional setup
   - Notification icons use app launcher icon

## 🎯 Future Enhancements

1. **Push Notifications** (FCM):
   - Send notifications even when app is closed
   - Requires Firebase setup
   - Package already included: `firebase_messaging`

2. **Notification Groups**:
   - Group chat messages by conversation
   - Stack MMP file notifications
   - Smart notification management

3. **Rich Notifications**:
   - Show user avatars
   - Inline reply for messages
   - File previews for MMP files

4. **Notification Settings**:
   - Allow users to toggle notification types
   - Set quiet hours
   - Customize notification sounds

## 📞 Support

For issues or questions:
- Check Flutter logs: `flutter logs`
- Enable debug mode in services
- Contact: francis.b.kaz@gmail.com

---

**Last Updated**: November 10, 2025
**Version**: 1.0.0
**Author**: AI Assistant
