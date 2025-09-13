// lib/authentication/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

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
    // Initialize animation controller with 1.5 second duration
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync:
          this, // vsync prevents animations from running when screen is not visible
    );

    // Create fade animation from 0 (invisible) to 1 (fully visible)
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut, // Smooth animation curve
      ),
    );

    // Start the animation when screen loads
    _animationController.forward();
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

  // Handle login logic
  Future<void> _handleLogin() async {
    // Validate form fields
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // Show loading indicator
      });

      // Simulate API call with 2 second delay
      await Future.delayed(const Duration(seconds: 2));

      // TODO: Implement actual login logic here
      // Example: await AuthService.login(_emailController.text, _passwordController.text);

      setState(() {
        _isLoading = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login successful!'),
          backgroundColor: AppColors.primaryBlue,
        ),
      );

      // Navigate to home screen (uncomment when home screen is created)
      // Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      // Container with gradient background
      body: Container(
        height: screenHeight,
        width: screenWidth,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryWhite, AppColors.backgroundGray],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            // Allows scrolling when keyboard appears
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // Company Logo/Icon Section
                    Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryOrange.withOpacity(
                                  0.25,
                                ),
                                blurRadius: 25,
                                offset: const Offset(0, 8),
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/pact_consultancy_pact_cover.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 200.ms)
                        .slideY(
                          begin: 0.2,
                          end: 0,
                          duration: 600.ms,
                          curve: Curves.easeOutQuad,
                        ),

                    const SizedBox(height: 30),

                    // Welcome Text
                    Text(
                          'Welcome Back!',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                            letterSpacing: 0.5,
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 300.ms)
                        .slideY(begin: 0.3, end: 0, duration: 500.ms),

                    const SizedBox(height: 12),

                    // Subtitle
                    Text(
                      'Sign in to your Pact Consultancy account',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textLight,
                      ),
                    ).animate().fadeIn(duration: 600.ms, delay: 400.ms),

                    const SizedBox(height: 40),

                    // Form Section
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Email Input Field
                          Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
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
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    hintText: 'Enter your email',
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.only(
                                        left: 16,
                                        right: 8,
                                      ),
                                      child: Icon(
                                        Icons.email_outlined,
                                        color: AppColors.primaryOrange,
                                      ),
                                    ),
                                    floatingLabelBehavior:
                                        FloatingLabelBehavior.auto,
                                  ),
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 600.ms, delay: 500.ms)
                              .slideY(begin: 0.3, end: 0, duration: 400.ms),

                          const SizedBox(height: 24),

                          // Password Input Field
                          Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
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
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    hintText: 'Enter your password',
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.only(
                                        left: 16,
                                        right: 8,
                                      ),
                                      child: Icon(
                                        Icons.lock_outline,
                                        color: AppColors.primaryOrange,
                                      ),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: AppColors.textLight,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isPasswordVisible =
                                              !_isPasswordVisible;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 600.ms, delay: 600.ms)
                              .slideY(begin: 0.3, end: 0, duration: 400.ms),

                          const SizedBox(height: 12),

                          // Forgot Password Link
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
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

                          const SizedBox(height: 30),

                          // Login Button
                          Container(
                                width: double.infinity,
                                height: 58,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryOrange
                                          .withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryOrange,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: AppColors
                                        .primaryOrange
                                        .withOpacity(0.7),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
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
                                      : Text(
                                          'SIGN IN',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.2,
                                          ),
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

                          const SizedBox(height: 30),

                          // Divider with OR text
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1.5,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.borderColor.withOpacity(
                                            0.1,
                                          ),
                                          AppColors.borderColor,
                                          AppColors.borderColor.withOpacity(
                                            0.1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    'OR',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textLight,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1.5,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.borderColor.withOpacity(
                                            0.1,
                                          ),
                                          AppColors.borderColor,
                                          AppColors.borderColor.withOpacity(
                                            0.1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 600.ms, delay: 900.ms),

                          const SizedBox(height: 20),

                          // Social Login Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Google Login Button
                              Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      onPressed: () {
                                        // TODO: Implement Google login
                                      },
                                      icon: const Icon(
                                        Icons
                                            .g_mobiledata, // Replace with actual Google icon
                                        size: 32,
                                        color: Color(0xFFDB4437), // Google red
                                      ),
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(duration: 600.ms, delay: 950.ms)
                                  .scale(
                                    begin: const Offset(0.9, 0.9),
                                    end: const Offset(1, 1),
                                  ),

                              const SizedBox(width: 24),

                              // Facebook Login Button
                              Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      onPressed: () {
                                        // TODO: Implement Facebook login
                                      },
                                      icon: const Icon(
                                        Icons
                                            .facebook, // Replace with actual Facebook icon
                                        size: 32,
                                        color: Color(
                                          0xFF1877F2,
                                        ), // Facebook blue
                                      ),
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(duration: 600.ms, delay: 1000.ms)
                                  .scale(
                                    begin: const Offset(0.9, 0.9),
                                    end: const Offset(1, 1),
                                  ),
                            ],
                          ),

                          const SizedBox(height: 40),

                          // Sign Up Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account?",
                                style: GoogleFonts.poppins(
                                  color: AppColors.textLight,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/register');
                                },
                                child: Text(
                                  'Sign Up',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.primaryOrange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    decoration: TextDecoration.underline,
                                    decorationThickness: 2,
                                  ),
                                ),
                              ),
                            ],
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
