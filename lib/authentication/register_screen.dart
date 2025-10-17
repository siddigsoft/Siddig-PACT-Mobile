// lib/authentication/register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  // Text field controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Animation controllers for staggered animations
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // State variables
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _acceptTerms = false;

  // Services
  final _authService = AuthService();

  // Build social sign in section
  Widget _buildSocialSignIn() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Or sign up with',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[300])),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 15,
                spreadRadius: -8,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: AppColors.borderColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                HapticFeedback.lightImpact();
                try {
                  setState(() => _isLoading = true);
                  final success = await _authService.signInWithGoogle();
                  if (mounted && success) {
                    Navigator.pushReplacementNamed(context, '/home');
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to sign in with Google'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error signing in with Google: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Center(
                  child: Icon(
                    Icons.g_mobiledata,
                    size: 32,
                    color: Color(0xFFDB4437), // Google red
                  ),
                ),
              ),
            ),
          ),
        ).animate()
        .fadeIn(duration: 600.ms, delay: 950.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();

    // Initialize fade animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Initialize slide animation controller
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Configure fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    // Configure slide animation (slides up from bottom)
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    // Clean up all controllers
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Name validation
  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your name';
    }
    if (value.length < 3) {
      return 'Name must be at least 3 characters';
    }
    // Check if name contains only letters and spaces
    final nameRegex = RegExp(r'^[a-zA-Z\s]+$');
    if (!nameRegex.hasMatch(value)) {
      return 'Name can only contain letters and spaces';
    }
    return null;
  }

  // Email validation
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  // Password validation with strength check
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    // Check for at least one uppercase letter
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    // Check for at least one number
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  // Confirm password validation
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  // Handle registration
  Future<void> _handleRegister() async {
    // Check if terms are accepted
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the terms and conditions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate form
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final response = await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
        );

        if (response.user != null) {
          // Registration successful
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      'Registration successful! Please check your email to confirm your account.',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.primaryOrange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 5),
              ),
            );
            // Navigate back to login
            Navigator.pop(context);
          }
        } else {
          throw Exception('Registration failed');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registration failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  // Password strength indicator
  Widget _buildPasswordStrengthIndicator(String password) {
    int strength = 0;
    String strengthText = 'Weak';
    Color strengthColor = AppColors.accentRed;

    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    switch (strength) {
      case 0:
      case 1:
        strengthText = 'Weak';
        strengthColor = AppColors.accentRed;
        break;
      case 2:
        strengthText = 'Medium';
        strengthColor = AppColors.accentYellow;
        break;
      case 3:
        strengthText = 'Strong';
        strengthColor = AppColors.primaryOrange;
        break;
      case 4:
        strengthText = 'Very Strong';
        strengthColor = AppColors.accentGreen;
        break;
    }

    return password.isEmpty
        ? const SizedBox.shrink()
        : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: strengthColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: strength / 4,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                strengthColor,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: strengthColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            strengthText,
                            style: TextStyle(
                              color: strengthColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
              .animate()
              .fadeIn(duration: 200.ms)
              .scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1, 1),
                duration: 200.ms,
              );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    // Back button with custom design
                    Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryOrange.withOpacity(
                                  0.08,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
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
                              width: 1.5,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                              },
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: AppColors.primaryOrange,
                                size: 18,
                              ),
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .slideX(
                          begin: -0.2,
                          end: 0,
                          duration: 500.ms,
                          curve: Curves.easeOutQuad,
                        ),
                    Expanded(
                      child:
                          Text(
                                'Create Account',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryOrange,
                                  letterSpacing: 0.5,
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 600.ms, delay: 200.ms)
                              .slideY(begin: -0.2, end: 0, duration: 400.ms),
                    ),
                    const SizedBox(width: 48), // Balance the layout
                  ],
                ),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),

                          // Welcome illustration/logo
                          Container(
                                width: 140,
                                height: 140,
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
                                      color: AppColors.primaryOrange
                                          .withOpacity(0.15),
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
                                    width: 5,
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
                              .scale(
                                begin: const Offset(0.9, 0.9),
                                end: const Offset(1, 1),
                                duration: 800.ms,
                                curve: Curves.easeOutQuint,
                              )
                              .shimmer(
                                duration: 1800.ms,
                                delay: 400.ms,
                                color: Colors.white.withOpacity(0.8),
                              ),

                          const SizedBox(height: 25),

                          // Subtitle
                          Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOrange.withOpacity(
                                    0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Fill in your details to get started',
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

                          const SizedBox(height: 30),

                          // Registration Form
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Full Name Field
                                TextFormField(
                                      controller: _nameController,
                                      keyboardType: TextInputType.name,
                                      validator: _validateName,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      decoration: InputDecoration(
                                        labelText: 'Full Name',
                                        hintText: 'Enter your full name',
                                        labelStyle: const TextStyle(
                                          color: AppColors.textLight,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.person_outline,
                                          color: AppColors.primaryOrange,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor: AppColors.primaryOrange
                                            .withOpacity(0.05),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 16,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: AppColors.primaryOrange
                                                .withOpacity(0.1),
                                            width: 1.5,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.primaryOrange,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 600.ms, delay: 300.ms)
                                    .slideX(
                                      begin: -0.1,
                                      end: 0,
                                      duration: 400.ms,
                                    ),

                                const SizedBox(height: 20),

                                // Email Field
                                TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: _validateEmail,
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                        hintText: 'Enter your email',
                                        labelStyle: const TextStyle(
                                          color: AppColors.textLight,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.email_outlined,
                                          color: AppColors.primaryOrange,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor: AppColors.primaryOrange
                                            .withOpacity(0.05),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 16,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: AppColors.primaryOrange
                                                .withOpacity(0.1),
                                            width: 1.5,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.primaryOrange,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 600.ms, delay: 400.ms)
                                    .slideX(
                                      begin: -0.1,
                                      end: 0,
                                      duration: 400.ms,
                                    ),

                                const SizedBox(height: 20),

                                // Password Field
                                Column(
                                  children: [
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: !_isPasswordVisible,
                                      validator: _validatePassword,
                                      onChanged: (value) => setState(
                                        () {},
                                      ), // Update strength indicator
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        hintText: 'Create a strong password',
                                        labelStyle: const TextStyle(
                                          color: AppColors.textLight,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                          color: AppColors.primaryOrange,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor: AppColors.primaryOrange
                                            .withOpacity(0.05),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 16,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: AppColors.primaryOrange
                                                .withOpacity(0.1),
                                            width: 1.5,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.primaryOrange,
                                            width: 2,
                                          ),
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _isPasswordVisible
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: AppColors.primaryOrange
                                                .withOpacity(0.7),
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
                                    _buildPasswordStrengthIndicator(
                                      _passwordController.text,
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                // Confirm Password Field
                                TextFormField(
                                      controller: _confirmPasswordController,
                                      obscureText: !_isConfirmPasswordVisible,
                                      validator: _validateConfirmPassword,
                                      decoration: InputDecoration(
                                        labelText: 'Confirm Password',
                                        hintText: 'Re-enter your password',
                                        labelStyle: const TextStyle(
                                          color: AppColors.textLight,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                          color: AppColors.primaryOrange,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor: AppColors.primaryOrange
                                            .withOpacity(0.05),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 16,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: AppColors.primaryOrange
                                                .withOpacity(0.1),
                                            width: 1.5,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.primaryOrange,
                                            width: 2,
                                          ),
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _isConfirmPasswordVisible
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: AppColors.primaryOrange
                                                .withOpacity(0.7),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _isConfirmPasswordVisible =
                                                  !_isConfirmPasswordVisible;
                                            });
                                          },
                                        ),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 600.ms, delay: 500.ms)
                                    .slideX(
                                      begin: -0.1,
                                      end: 0,
                                      duration: 400.ms,
                                    ),

                                const SizedBox(height: 20),

                                // Terms and Conditions Checkbox
                                Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryOrange
                                            .withOpacity(0.04),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.primaryOrange
                                              .withOpacity(0.1),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: Transform.scale(
                                              scale: 0.9,
                                              child: Checkbox(
                                                value: _acceptTerms,
                                                onChanged: (value) {
                                                  setState(() {
                                                    _acceptTerms =
                                                        value ?? false;
                                                  });
                                                  if (value == true) {
                                                    HapticFeedback.lightImpact();
                                                  }
                                                },
                                                activeColor:
                                                    AppColors.primaryOrange,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                side: BorderSide(
                                                  color: AppColors.primaryOrange
                                                      .withOpacity(0.6),
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _acceptTerms = !_acceptTerms;
                                                });
                                                if (_acceptTerms) {
                                                  HapticFeedback.lightImpact();
                                                }
                                              },
                                              child: RichText(
                                                text: TextSpan(
                                                  style: GoogleFonts.poppins(
                                                    color: AppColors.textLight,
                                                    fontSize: 14,
                                                  ),
                                                  children: [
                                                    const TextSpan(
                                                      text: 'I agree to the ',
                                                    ),
                                                    TextSpan(
                                                      text:
                                                          'Terms & Conditions',
                                                      style: GoogleFonts.poppins(
                                                        color: AppColors
                                                            .primaryOrange,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        decoration:
                                                            TextDecoration
                                                                .underline,
                                                        decorationColor:
                                                            AppColors
                                                                .primaryOrange
                                                                .withOpacity(
                                                                  0.4,
                                                                ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 600.ms, delay: 550.ms)
                                    .slideY(
                                      begin: 0.2,
                                      end: 0,
                                      duration: 400.ms,
                                    ),

                                const SizedBox(height: 30),

                                // Register Button
                                Container(
                                      width: double.infinity,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryOrange
                                                .withOpacity(0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                            spreadRadius: -2,
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _isLoading
                                            ? null
                                            : () {
                                                HapticFeedback.mediumImpact();
                                                _handleRegister();
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.5,
                                                    ),
                                              )
                                            : Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Text(
                                                    'CREATE ACCOUNT',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 1,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Icon(
                                                    Icons.arrow_forward_rounded,
                                                    color: Colors.white
                                                        .withOpacity(0.9),
                                                    size: 20,
                                                  ),
                                                ],
                                              ),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 800.ms, delay: 600.ms)
                                    .slideY(
                                      begin: 0.3,
                                      end: 0,
                                      duration: 500.ms,
                                      curve: Curves.easeOutQuint,
                                    ),

                                const SizedBox(height: 30),

                                // Social sign in section
                                _buildSocialSignIn(),

                                const SizedBox(height: 30),

                                // Already have account link
                                Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppColors.primaryOrange
                                              .withOpacity(0.15),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Already have an account?',
                                            style: GoogleFonts.poppins(
                                              color: AppColors.textLight,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              HapticFeedback.lightImpact();
                                              Navigator.pushReplacementNamed(
                                                context,
                                                '/login',
                                              );
                                            },
                                            style: TextButton.styleFrom(
                                              minimumSize: Size.zero,
                                              padding: const EdgeInsets.only(
                                                left: 8,
                                                right: 4,
                                              ),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: Row(
                                              children: [
                                                Text(
                                                  'Sign In',
                                                  style: GoogleFonts.poppins(
                                                    color:
                                                        AppColors.primaryOrange,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.login_rounded,
                                                  color:
                                                      AppColors.primaryOrange,
                                                  size: 16,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 800.ms, delay: 700.ms)
                                    .slideY(
                                      begin: 0.2,
                                      end: 0,
                                      duration: 400.ms,
                                    ),

                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
