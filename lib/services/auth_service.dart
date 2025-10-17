import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
          'Display name': user.userMetadata?['full_name'] ?? user.email?.split('@')[0] ?? 'User',
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
    // Add any cleanup needed on sign out
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
            ? 'http://localhost:8080'  // Local development URL
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
}