// lib/authentication/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // Controllers for text fields - manages the text input
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Animation controller for smooth animations
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Boolean to toggle password visibility
  bool _isPasswordVisible = false;

  // Boolean to track loading state
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize animation controller with 1.8 second duration for smoother animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync:
          this, // vsync prevents animations from running when screen is not visible
    );

    // Create fade animation from 0 (invisible) to 1 (fully visible)
    // Using a custom curve for more modern feel
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 1.0, curve: Curves.fastOutSlowIn),
      ),
    );

    // Start the animation with a slight delay for a more natural feel
    Future.delayed(const Duration(milliseconds: 100), () {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    // Clean up controllers when widget is removed
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Email validation function
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    // Regular expression for email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null; // null means validation passed
  }

  // Password validation function
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // Handle login logic with improved animations and role check
  Future<void> _handleLogin() async {
    // Validate form fields
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      setState(() {
        _isLoading = true; // Show loading indicator
      });

      try {
        final authService = AuthService();
        final response = await authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Check if user is a data collector
        final userId = response.user?.id;
        if (userId != null) {
          final dataCollectorCheck = await authService.supabase
              .from('user_roles')
              .select()
              .eq('user_id', userId)
              .eq('role', 'data_collector')
              .single();

          if (dataCollectorCheck != null) {
            if (mounted) {
              // Haptic feedback for successful login
              HapticFeedback.mediumImpact();
              // Navigate to main screen
              Navigator.pushReplacementNamed(context, '/main');
            }
          } else {
            throw Exception('Access denied: User is not a data collector');
          }
        }
      } catch (e) {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Login failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }

      // Show modern success message with animation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'Login successful!',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );

      // Navigate to the main screen with bottom navigation
      // Use direct navigation instead of utility
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      // Container with gradient background and pattern
      body: Container(
        height: screenHeight,
        width: screenWidth,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryWhite,
              AppColors.backgroundGray.withOpacity(0.8),
              AppColors.backgroundGray,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            // Allows scrolling when keyboard appears
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: screenHeight * 0.05),

                    // Company Logo/Icon Section
                    Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.white,
                                AppColors.backgroundGray.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryOrange.withOpacity(
                                  0.15,
                                ),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                                spreadRadius: -5,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                                spreadRadius: 0,
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.95),
                              width: 6,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/pact_consultancy_pact_cover.jpg',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 800.ms, delay: 200.ms)
                        .slideY(
                          begin: 0.2,
                          end: 0,
                          duration: 800.ms,
                          curve: Curves.easeOutQuint,
                        )
                        .shimmer(
                          duration: 1800.ms,
                          delay: 400.ms,
                          color: Colors.white.withOpacity(0.8),
                        ),

                    SizedBox(height: screenHeight * 0.03),

                    // Welcome Text
                    Text(
                          'Welcome Back!',
                          style: GoogleFonts.poppins(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                            letterSpacing: 0.5,
                            height: 1.1,
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 800.ms, delay: 300.ms)
                        .slideY(begin: 0.3, end: 0, duration: 600.ms)
                        .shimmer(
                          duration: 1200.ms,
                          delay: 700.ms,
                          color: AppColors.primaryOrange.withOpacity(0.2),
                        ),

                    SizedBox(height: screenHeight * 0.018),

                    // Subtitle
                    Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Sign in to your Pact Consultancy account',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textLight,
                              letterSpacing: 0.2,
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 800.ms, delay: 400.ms)
                        .slideY(begin: 0.3, end: 0, duration: 500.ms),

                    SizedBox(height: screenHeight * 0.04),

                    // Form Section
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Email Input Field
                          Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                      spreadRadius: -5,
                                    ),
                                  ],
                                ),
                                child: TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: _validateEmail,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    hintText: 'Enter your email',
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 22,
                                    ),
                                    prefixIcon: Container(
                                      margin: const EdgeInsets.only(
                                        left: 16,
                                        right: 12,
                                      ),
                                      child: const Icon(
                                        Icons.email_outlined,
                                        color: AppColors.primaryOrange,
                                        size: 22,
                                      ),
                                    ),
                                    floatingLabelBehavior:
                                        FloatingLabelBehavior.auto,
                                    labelStyle: TextStyle(
                                      color: AppColors.textLight.withOpacity(
                                        0.8,
                                      ),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 600.ms, delay: 500.ms)
                              .slideY(begin: 0.3, end: 0, duration: 400.ms),

                          SizedBox(height: screenHeight * 0.025),

                          // Password Input Field
                          Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                      spreadRadius: -5,
                                    ),
                                  ],
                                ),
                                child: TextFormField(
                                  controller: _passwordController,
                                  obscureText:
                                      !_isPasswordVisible, // Hide/show password
                                  validator: _validatePassword,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    hintText: 'Enter your password',
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 22,
                                    ),
                                    prefixIcon: Container(
                                      margin: const EdgeInsets.only(
                                        left: 16,
                                        right: 12,
                                      ),
                                      child: const Icon(
                                        Icons.lock_outline,
                                        color: AppColors.primaryOrange,
                                        size: 22,
                                      ),
                                    ),
                                    suffixIcon: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      child: IconButton(
                                        icon: Icon(
                                          _isPasswordVisible
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: AppColors.textLight,
                                          size: 22,
                                        ),
                                        splashRadius: 20,
                                        onPressed: () {
                                          setState(() {
                                            _isPasswordVisible =
                                                !_isPasswordVisible;
                                          });
                                        },
                                      ),
                                    ),
                                    labelStyle: TextStyle(
                                      color: AppColors.textLight.withOpacity(
                                        0.8,
                                      ),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 600.ms, delay: 600.ms)
                              .slideY(begin: 0.3, end: 0, duration: 400.ms),

                          SizedBox(height: screenHeight * 0.015),

                          // Forgot Password Link
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                Navigator.pushNamed(
                                  context,
                                  '/forgot-password',
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                foregroundColor: AppColors.primaryOrange,
                              ),
                              child: Text(
                                'Forgot Password?',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ).animate().fadeIn(duration: 600.ms, delay: 700.ms),

                          SizedBox(height: screenHeight * 0.035),

                          // Login Button
                          Container(
                                width: double.infinity,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.primaryOrange,
                                      AppColors.lightOrange,
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryOrange
                                          .withOpacity(0.25),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                      spreadRadius: -5,
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.transparent,
                                    disabledForegroundColor: Colors.white
                                        .withOpacity(0.8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'SIGN IN',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 600.ms, delay: 800.ms)
                              .slideY(
                                begin: 0.3,
                                end: 0,
                                duration: 400.ms,
                                curve: Curves.easeOutQuint,
                              ),

                          SizedBox(height: screenHeight * 0.035),

                          // Divider with OR text
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1.2,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.borderColor.withOpacity(
                                            0.05,
                                          ),
                                          AppColors.borderColor.withOpacity(
                                            0.6,
                                          ),
                                          AppColors.borderColor.withOpacity(
                                            0.05,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundGray.withOpacity(
                                      0.5,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.borderColor.withOpacity(
                                        0.2,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'OR',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textLight,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1.2,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.borderColor.withOpacity(
                                            0.05,
                                          ),
                                          AppColors.borderColor.withOpacity(
                                            0.6,
                                          ),
                                          AppColors.borderColor.withOpacity(
                                            0.05,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 600.ms, delay: 900.ms),

                          SizedBox(height: screenHeight * 0.025),

                          // Social Login Buttons
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Google Login Button
                                Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.03,
                                            ),
                                            blurRadius: 15,
                                            spreadRadius: -8,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: AppColors.borderColor
                                              .withOpacity(0.1),
                                          width: 1,
                                        ),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            // TODO: Implement Google login
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(12.0),
                                            child: Center(
                                              child: Icon(
                                                Icons
                                                    .g_mobiledata, // Replace with actual Google icon
                                                size: 32,
                                                color: Color(
                                                  0xFFDB4437,
                                                ), // Google red
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 600.ms, delay: 950.ms)
                                    .scale(
                                      begin: const Offset(0.9, 0.9),
                                      end: const Offset(1, 1),
                                      curve: Curves.easeOutBack,
                                    ),

                                // Facebook Login Button
                                Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.03,
                                            ),
                                            blurRadius: 15,
                                            spreadRadius: -8,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: AppColors.borderColor
                                              .withOpacity(0.1),
                                          width: 1,
                                        ),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            // TODO: Implement Facebook login
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(12.0),
                                            child: Center(
                                              child: Icon(
                                                Icons.facebook,
                                                size: 32,
                                                color: Color(
                                                  0xFF1877F2,
                                                ), // Facebook blue
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 600.ms, delay: 1000.ms)
                                    .scale(
                                      begin: const Offset(0.9, 0.9),
                                      end: const Offset(1, 1),
                                      curve: Curves.easeOutBack,
                                    ),

                                // Apple Login Button
                                Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.03,
                                            ),
                                            blurRadius: 15,
                                            spreadRadius: -8,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: AppColors.borderColor
                                              .withOpacity(0.1),
                                          width: 1,
                                        ),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            // TODO: Implement Apple login
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(12.0),
                                            child: Center(
                                              child: Icon(
                                                Icons.apple,
                                                size: 32,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 600.ms, delay: 1050.ms)
                                    .scale(
                                      begin: const Offset(0.9, 0.9),
                                      end: const Offset(1, 1),
                                      curve: Curves.easeOutBack,
                                    ),
                              ],
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.045),

                          // Sign Up Link
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account?",
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textLight,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.pushNamed(context, '/register');
                                  },
                                  style: TextButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    foregroundColor: AppColors.primaryOrange,
                                  ),
                                  child: Text(
                                    'Sign Up',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.primaryOrange,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      decoration: TextDecoration.underline,
                                      decorationThickness: 2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 600.ms, delay: 1100.ms),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
