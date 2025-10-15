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
      // Check if user profile exists
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        // Create new profile if doesn't exist
        await supabase.from('profiles').insert({
          'id': user.id,
          'email': user.email,
          'full_name': user.userMetadata?['full_name'] ?? user.email?.split('@')[0],
          'avatar_url': user.userMetadata?['avatar_url'],
          'status': 'online',
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

  // Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await supabase.auth.signUp(
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