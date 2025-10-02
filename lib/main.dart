// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'authentication/login_screen.dart';
import 'authentication/register_screen.dart';
import 'authentication/forgot_password_screen.dart';
import 'screens/main_screen.dart';
import 'screens/field_operations_enhanced_screen.dart';
import 'theme/app_colors.dart';
import 'utils/environment.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/data_sync_service.dart';

// Conditionally import web plugins only when needed
// This prevents errors on non-web platforms
import 'utils/web_config.dart'
    if (dart.library.html) 'utils/web_config_web.dart';

// Global navigator key to use for navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: Environment.supabaseUrl,
    anonKey: Environment.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // Initialize services
  AuthService();
  StorageService();
  DataSyncService();
  // Ensures Flutter widgets are initialized before running the app
  WidgetsFlutterBinding.ensureInitialized();

  // Configure URL strategy for web platform only
  configureApp();

  // Debug log - helpful for troubleshooting routing
  debugPrint('🚀 Starting PACT Consultancy app');

  // Sets the status bar to be transparent for a modern look
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Set up a route observer for logging navigation (helps with debugging)
  final routeObserver = RouteObserver<PageRoute>();

  // Debug logging for route handling
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exception.toString().contains('no route')) {
      debugPrint('❌ ROUTE ERROR: ${details.exception}');
    }
    FlutterError.presentError(details);
  };

  // Runs the main application
  runApp(MyApp(routeObserver: routeObserver));
}

class MyApp extends StatelessWidget {
  final RouteObserver<PageRoute>? routeObserver;

  const MyApp({super.key, this.routeObserver});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // App title shown in task switcher
      title: 'Pact Consultancy',

      // Removes the debug banner in the top-right corner
      debugShowCheckedModeBanner: false,

      // Use the centralized theme from AppColors
      theme: AppColors.themeData,

      // Set up routing for proper URL display
      // Do not set home when using initialRoute
      initialRoute: '/login',

      // Define routes for navigation throughout the app
      routes: {
        '/': (_) => const LoginScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),
        '/main': (_) => const MainScreen(),
        '/field-operations': (_) => const FieldOperationsEnhancedScreen(),
      },

      // Backup with onGenerateRoute for dynamic routes and better debugging
      onGenerateRoute: (settings) {
        debugPrint('⚠️ Fallback route generation: ${settings.name}');

        // Only for routes not defined in routes map
        switch (settings.name) {
          case '/login':
          case '/register':
          case '/forgot-password':
          case '/main':
          case '/':
            // These should be handled by the routes map above
            // Just a fallback
            final routeBuilders = {
              '/': (_) => const LoginScreen(),
              '/login': (_) => const LoginScreen(),
              '/register': (_) => const RegisterScreen(),
              '/forgot-password': (_) => const ForgotPasswordScreen(),
              '/main': (_) => const MainScreen(),
            };

            final builder = routeBuilders[settings.name];
            if (builder != null) {
              return PageRouteBuilder(
                settings: settings,
                pageBuilder: (context, animation, secondaryAnimation) =>
                    builder(context),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
              );
            }
            return null;
          default:
            // If route not found, pass to onUnknownRoute
            return null;
        }
      },

      // Handle unknown routes (404 page)
      onUnknownRoute: (settings) {
        debugPrint('Unknown route: ${settings.name}');
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(child: Text('Page not found: ${settings.name}')),
          ),
        );
      },

      // Add route observer for logging navigation
      navigatorObservers: [if (routeObserver != null) routeObserver!],

      // Use global navigator key for navigation
      navigatorKey: navigatorKey,
    );
  }
}
