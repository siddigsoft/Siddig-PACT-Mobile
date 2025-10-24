import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles all authentication-related operations
class AuthService {
  final supabase = Supabase.instance.client;

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Listen for auth state changes
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        // Handle sign in
        _handleSignIn(data.session?.user);
      } else if (data.event == AuthChangeEvent.signedOut) {
        // Handle sign out
        _handleSignOut();
      }
    });

    _initialized = true;
  }

  Future<void> _handleSignIn(User? user) async {
    if (user == null) return;

    try {
      // Store auth data locally for offline access
      final session = supabase.auth.currentSession;
      if (session != null) {
        await _storeAuthDataLocally(session);
      }

      // Check if user profile exists in Users table
      final profile = await supabase
          .from('Users')
          .select()
          .eq('UID', user.id)
          .maybeSingle();

      if (profile == null) {
        // Create new user profile if doesn't exist
        await supabase.from('Users').insert({
          'UID': user.id,
          'Display name': user.userMetadata?['full_name'] ??
              user.email?.split('@')[0] ??
              'User',
          'Email': user.email,
          'phone': user.userMetadata?['phone'],
          'Providers': ['email'],
          'Provider type': 'email',
          'Created at': DateTime.now().toIso8601String(),
          'Last sign in at': DateTime.now().toIso8601String(),
          'status': 'online',
        });
      } else {
        // Update last sign in time
        await supabase.from('Users').update({
          'Last sign in at': DateTime.now().toIso8601String(),
        }).eq('UID', user.id);
      }

      // Ensure user has data_collector role
      final role = await supabase
          .from('user_roles')
          .select()
          .eq('user_id', user.id)
          .eq('role', 'data_collector')
          .maybeSingle();

      if (role == null) {
        await supabase.from('user_roles').insert({
          'user_id': user.id,
          'role': 'data_collector',
        });
      }
    } catch (e) {
      debugPrint('Error handling sign in: $e');
    }
  }

  void _handleSignOut() {
    // Clear local authentication data
    _clearLocalAuthData();
    // Add any other cleanup needed on sign out
  }

  // Stream of auth changes
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  // Current user
  User? get currentUser => supabase.auth.currentUser;

  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      if (kDebugMode) {
        print('Auth error: ${e.message}');
      }
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('An unexpected error occurred');
    }
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: name != null ? {'full_name': name} : null,
      );
      return response;
    } on AuthException catch (e) {
      if (kDebugMode) {
        print('Auth error: ${e.message}');
      }
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('An unexpected error occurred');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
      // Clear local authentication data
      await _clearLocalAuthData();
    } catch (e) {
      throw AuthException('Failed to sign out');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw AuthException('Failed to send reset password email');
    }
  }

  /// Signs in user with Google OAuth using platform-specific approach
  Future<bool> signInWithGoogle() async {
    try {
      final response = await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? 'http://localhost:8080' // Local development URL
            : 'io.supabase.pact://login-callback/',
      );

      if (response) {
        final session = supabase.auth.currentSession;
        if (session != null) {
          await _handleSignIn(session.user);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Google sign in error: $e');
      return false;
    }
  }

  // ===== LOCAL STORAGE METHODS =====

  /// Store authentication data locally for offline access
  Future<void> _storeAuthDataLocally(Session session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', session.accessToken);
      await prefs.setString('refresh_token', session.refreshToken ?? '');
      await prefs.setString('user_id', session.user.id);
      await prefs.setString('user_email', session.user.email ?? '');
      await prefs.setString(
          'user_name', session.user.userMetadata?['full_name'] ?? '');
      await prefs.setBool('is_logged_in', true);
      await prefs.setInt('token_expires_at', session.expiresAt ?? 0);
    } catch (e) {
      debugPrint('Error storing auth data locally: $e');
    }
  }

  /// Clear local authentication data
  Future<void> _clearLocalAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('refresh_token');
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      await prefs.remove('user_name');
      await prefs.setBool('is_logged_in', false);
      await prefs.remove('token_expires_at');
    } catch (e) {
      debugPrint('Error clearing local auth data: $e');
    }
  }

  /// Get locally stored authentication data
  Future<Map<String, dynamic>?> getLocalAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      if (!isLoggedIn) return null;

      final token = prefs.getString('auth_token');
      final refreshToken = prefs.getString('refresh_token');
      final userId = prefs.getString('user_id');
      final userEmail = prefs.getString('user_email');
      final userName = prefs.getString('user_name');
      final expiresAt = prefs.getInt('token_expires_at');

      if (token == null || userId == null) return null;

      // Check if token is expired
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (expiresAt != null && now > expiresAt) {
        await _clearLocalAuthData();
        return null;
      }

      return {
        'access_token': token,
        'refresh_token': refreshToken,
        'user_id': userId,
        'user_email': userEmail,
        'user_name': userName,
        'expires_at': expiresAt,
      };
    } catch (e) {
      debugPrint('Error getting local auth data: $e');
      return null;
    }
  }

  /// Check if user is logged in locally (for offline access)
  Future<bool> isLoggedInLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_logged_in') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get cached user profile data
  Future<Map<String, dynamic>?> getLocalUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final userEmail = prefs.getString('user_email');
      final userName = prefs.getString('user_name');

      if (userId == null) return null;

      return {
        'id': userId,
        'email': userEmail,
        'name': userName,
      };
    } catch (e) {
      debugPrint('Error getting local user profile: $e');
      return null;
    }
  }

  /// Store user preferences locally
  Future<void> storeUserPreferences(Map<String, dynamic> preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      preferences.forEach((key, value) async {
        if (value is String) {
          await prefs.setString('pref_$key', value);
        } else if (value is bool) {
          await prefs.setBool('pref_$key', value);
        } else if (value is int) {
          await prefs.setInt('pref_$key', value);
        } else if (value is double) {
          await prefs.setDouble('pref_$key', value);
        }
      });
    } catch (e) {
      debugPrint('Error storing user preferences: $e');
    }
  }

  /// Get user preferences from local storage
  Future<Map<String, dynamic>> getUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final preferences = <String, dynamic>{};

      // Get all keys that start with 'pref_'
      final keys = prefs.getKeys().where((key) => key.startsWith('pref_'));

      for (final key in keys) {
        final value = prefs.get(key);
        if (value != null) {
          preferences[key.substring(5)] = value; // Remove 'pref_' prefix
        }
      }

      return preferences;
    } catch (e) {
      debugPrint('Error getting user preferences: $e');
      return {};
    }
  }
}
