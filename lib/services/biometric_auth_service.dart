import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _userEmailKey = 'biometric_user_email';

  /// Check if device supports biometric authentication
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

  /// Get friendly name for biometric type
  String getBiometricTypeName(List<BiometricType> biometrics) {
    if (biometrics.isEmpty) return 'Biometric';
    
    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (biometrics.contains(BiometricType.iris)) {
      return 'Iris';
    } else {
      return 'Biometric';
    }
  }

  /// Authenticate user with biometrics
  Future<bool> authenticate({String reason = 'Please authenticate to access the app'}) async {
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

      // Use device biometrics if available, fallback to device PIN/pattern when allowed
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // allow device credential fallback
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      print('Error during biometric authentication: $e');
      return false;
    } on MissingPluginException {
      return false;
    }
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
