import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _userEmailKey = 'biometric_user_email';

  /// Check if device supports biometric authentication
  /// Uses both canCheckBiometrics and isDeviceSupported as per official docs
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) {
      return false;
    }
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (e) {
      print('Error checking biometric availability: $e');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Get list of available biometric types (fingerprint, face, etc.)
  /// Returns enrolled biometrics on the device
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) {
      return [];
    }
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    } on MissingPluginException {
      return [];
    }
  }

  /// Check if any biometrics are enrolled on the device
  /// As per docs: canCheckBiometrics only checks hardware, not enrollment
  Future<bool> hasEnrolledBiometrics() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.isNotEmpty;
  }

  /// Get friendly name for biometric type
  String getBiometricTypeName(List<BiometricType> biometrics) {
    if (biometrics.isEmpty) return 'Biometric';
    
    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.strong)) {
      return 'Biometric (Strong)';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (biometrics.contains(BiometricType.weak)) {
      return 'Biometric (Weak)';
    } else if (biometrics.contains(BiometricType.iris)) {
      return 'Iris';
    } else {
      return 'Biometric';
    }
  }

  /// Authenticate user with biometrics
  /// Enhanced with platform-specific dialog customization and proper error handling
  Future<bool> authenticate({
    String reason = 'Please authenticate to access the app',
    bool biometricOnly = false,
    bool persistAcrossBackgrounding = false,
    bool useCustomDialog = true,
  }) async {
    if (kIsWeb) {
      return false;
    }
    try {
      // Ensure device supports biometrics or device credentials
      final canUseBiometrics = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canUseBiometrics && !isSupported) {
        print('Biometric/device authentication not supported on this device');
        return false;
      }

      // Platform-specific dialog customization as per official docs
      final List<AuthMessages> authMessages = useCustomDialog
          ? <AuthMessages>[
              const AndroidAuthMessages(
                signInTitle: 'Biometric Authentication Required',
                cancelButton: 'Cancel',
                biometricHint: 'Verify your identity',
                biometricNotRecognized: 'Not recognized. Try again.',
                biometricSuccess: 'Authentication successful',
                deviceCredentialsRequiredTitle: 'Device Credential Required',
                deviceCredentialsSetupDescription: 'Please set up device credentials',
                goToSettingsButton: 'Go to Settings',
                goToSettingsDescription: 'Biometric authentication is not set up on your device. Go to Settings > Security to add biometric authentication.',
              ),
              const IOSAuthMessages(
                cancelButton: 'Cancel',
                goToSettingsButton: 'Settings',
                goToSettingsDescription: 'Biometric authentication is not set up. Please set up Touch ID or Face ID.',
                lockOut: 'Biometric authentication is locked. Please try again later.',
              ),
            ]
          : const <AuthMessages>[];

      // Authenticate with configured options
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        authMessages: authMessages,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      // Handle specific error codes as per official documentation
      if (e.code == auth_error.notAvailable) {
        print('Biometric authentication not available on this device');
      } else if (e.code == auth_error.notEnrolled) {
        print('No biometric credentials enrolled. Please set up biometric authentication in device settings.');
      } else if (e.code == auth_error.lockedOut) {
        print('Too many failed attempts. Biometric authentication is temporarily locked.');
      } else if (e.code == auth_error.permanentlyLockedOut) {
        print('Too many failed attempts. Biometric authentication is permanently locked.');
      } else if (e.code == auth_error.passcodeNotSet) {
        print('Passcode not set. Please set up a passcode in device settings.');
      } else {
        print('Error during biometric authentication: $e');
      }
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Authenticate with biometric only (no device credential fallback)
  /// As per docs: requires biometric authentication explicitly
  Future<bool> authenticateBiometricOnly({
    String reason = 'Please authenticate with biometrics',
  }) async {
    // Check if biometrics are enrolled
    final hasEnrolled = await hasEnrolledBiometrics();
    if (!hasEnrolled) {
      print('No biometrics enrolled on device');
      return false;
    }

    return authenticate(
      reason: reason,
      biometricOnly: true,
    );
  }

  /// Authenticate with background handling support
  /// As per docs: persistAcrossBackgrounding prevents cancellation when app is backgrounded
  Future<bool> authenticateWithBackgroundHandling({
    String reason = 'Please authenticate to access the app',
  }) async {
    return authenticate(
      reason: reason,
      persistAcrossBackgrounding: true,
    );
  }

  /// Check if biometric login is enabled for the user
  Future<bool> isBiometricEnabled() async {
    try {
      final String? enabled = await _secureStorage.read(key: _biometricEnabledKey);
      return enabled == 'true';
    } catch (e) {
      print('Error checking if biometric is enabled: $e');
      return false;
    }
  }

  /// Enable biometric authentication for user
  Future<void> enableBiometric(String userEmail) async {
    try {
      await _secureStorage.write(key: _biometricEnabledKey, value: 'true');
      await _secureStorage.write(key: _userEmailKey, value: userEmail);
    } catch (e) {
      print('Error enabling biometric: $e');
      throw Exception('Failed to enable biometric authentication');
    }
  }

  /// Disable biometric authentication
  Future<void> disableBiometric() async {
    try {
      await _secureStorage.delete(key: _biometricEnabledKey);
      await _secureStorage.delete(key: _userEmailKey);
    } catch (e) {
      print('Error disabling biometric: $e');
      throw Exception('Failed to disable biometric authentication');
    }
  }

  /// Get stored user email for biometric login
  Future<String?> getBiometricUserEmail() async {
    try {
      return await _secureStorage.read(key: _userEmailKey);
    } catch (e) {
      print('Error getting biometric user email: $e');
      return null;
    }
  }

  /// Store user credentials securely (only for biometric login)
  Future<void> storeCredentials(String email, String password) async {
    try {
      await _secureStorage.write(key: 'user_email', value: email);
      await _secureStorage.write(key: 'user_password', value: password);
    } catch (e) {
      print('Error storing credentials: $e');
      throw Exception('Failed to store credentials');
    }
  }

  /// Get stored credentials (for biometric login)
  Future<Map<String, String?>> getStoredCredentials() async {
    try {
      final email = await _secureStorage.read(key: 'user_email');
      final password = await _secureStorage.read(key: 'user_password');
      return {'email': email, 'password': password};
    } catch (e) {
      print('Error getting stored credentials: $e');
      return {'email': null, 'password': null};
    }
  }

  /// Clear stored credentials
  Future<void> clearStoredCredentials() async {
    try {
      await _secureStorage.delete(key: 'user_email');
      await _secureStorage.delete(key: 'user_password');
    } catch (e) {
      print('Error clearing credentials: $e');
    }
  }
}
