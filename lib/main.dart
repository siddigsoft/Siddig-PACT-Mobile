// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'authentication/login_screen.dart';
import 'authentication/register_screen.dart';
import 'authentication/forgot_password_screen.dart';
import 'theme/app_colors.dart';

void main() {
  // Ensures Flutter widgets are initialized before running the app
  WidgetsFlutterBinding.ensureInitialized();

  // Sets the status bar to be transparent for a modern look
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Runs the main application
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // App title shown in task switcher
      title: 'Pact Consultancy',

      // Removes the debug banner in the top-right corner
      debugShowCheckedModeBanner: false,

      // Define the app's theme
      theme: ThemeData(
        // Sets the primary color scheme
        primaryColor: AppColors.primaryOrange,

        // Use Material 3 design
        useMaterial3: true,

        // Defines color scheme for the entire app
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryOrange,
          primary: AppColors.primaryOrange,
          secondary: AppColors.primaryBlue,
          surface: AppColors.primaryWhite,
          background: AppColors.backgroundGray,
          brightness: Brightness.light,
        ),

        // Configures the AppBar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0, // Removes shadow
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.textDark),
          titleTextStyle: TextStyle(
            color: AppColors.textDark,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),

        // Configures elevated button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),

        // Configures text button theme
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryOrange,
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Configures input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.primaryOrange,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),

          // Modern styling for labels and hints
          labelStyle: const TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: const TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.w400,
          ),
          floatingLabelStyle: const TextStyle(
            color: AppColors.primaryOrange,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Sets the initial route when app starts
      initialRoute: '/login',

      // Define all the routes in your app
      routes: {
        '/login': (context) => const LoginScreen(), // Login page route
        '/register': (context) => const RegisterScreen(), // Register page route
        '/forgot-password': (context) =>
            const ForgotPasswordScreen(), // Forgot password route
        // Add more routes here as your app grows
        // '/home': (context) => const HomeScreen(),
      },

      // Handle unknown routes (404 page)
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(child: Text('Page not found: ${settings.name}')),
          ),
        );
      },
    );
  }
}
