// lib/authentication/improved_register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_design_system.dart';
import '../widgets/app_widgets.dart';
import '../services/auth_service.dart';

class ImprovedRegisterScreen extends StatefulWidget {
  const ImprovedRegisterScreen({super.key});

  @override
  State<ImprovedRegisterScreen> createState() => _ImprovedRegisterScreenState();
}

class _ImprovedRegisterScreenState extends State<ImprovedRegisterScreen>
    with SingleTickerProviderStateMixin {
  // Controllers
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _employeeIdController = TextEditingController();

  // State
  String? _selectedRole;
  String? _selectedHub;
  bool _isPasswordVisible = false;
  bool _acceptTerms = false;
  bool _isLoading = false;

  // Dropdown options matching web implementation
  final List<String> _roles = [
    'Data Collector',
    'Coordinator',
    'Supervisor',
    'Admin',
    'ICT',
    'FOM',
  ];

  final List<String> _hubs = [
    'Kassala hub',
    'Kosti hub',
    'El Fasher hub',
    'Dongola hub',
    'Country Office',
  ];

  // Services
  final _authService = AuthService();

  // Animation
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }

  // Validation
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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String? _validateRole(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please select a role';
    }
    return null;
  }

  String? _validateHub(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please select a hub';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    return null;
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptTerms) {
      AppSnackBar.show(
        context,
        message: 'Please accept the terms and conditions',
        type: SnackBarType.warning,
      );
      return;
    }

    // Prevent multiple submissions
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    AppLoadingOverlay.show(context, message: 'Creating your account...');

    try {
      // Register user
      final response = await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
      );

      if (response.user != null) {
        // Wait 2 seconds to avoid rate limiting (Supabase requirement)
        await Future.delayed(const Duration(seconds: 2));

        // Create user profile with all fields
        try {
          await _authService.supabase.from('profiles').upsert({
            'id': response.user!.id,
            'full_name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'role': _selectedRole,
            'hub_id': _selectedHub, // Changed from 'hub' to 'hub_id'
            'employee_id': _employeeIdController.text.trim().isNotEmpty
                ? _employeeIdController.text.trim()
                : null,
            'status': 'active',
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          print('Profile creation error: $e');
          // Continue even if profile creation fails
        }

        // Wait another second before role assignment
        await Future.delayed(const Duration(seconds: 1));

        // Assign role in user_roles table
        try {
          await _authService.supabase.from('user_roles').insert({
            'user_id': response.user!.id,
            'role': _selectedRole,
          });
        } catch (e) {
          print('Role assignment error: $e');
          // Continue even if role assignment fails
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          AppLoadingOverlay.hide(context);
          HapticFeedback.mediumImpact();

          // Show success dialog
          await AppSuccessDialog.show(
            context,
            title: 'Welcome to PACT!',
            message:
                'Your account has been created successfully. Please check your email to verify your account.',
            actionText: 'Go to Login',
            onAction: () => Navigator.pushReplacementNamed(context, '/login'),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        AppLoadingOverlay.hide(context);

        String errorMessage =
            'Unable to create your account. Please check your information and try again.';

        // Parse specific error messages
        if (e.toString().contains('already registered') ||
            e.toString().contains('already exists')) {
          errorMessage =
              'This email is already registered. Please use a different email or try logging in.';
        } else if (e.toString().contains('Too Many Requests') ||
            e.toString().contains('rate limit')) {
          errorMessage =
              'Too many registration attempts. Please wait a moment and try again.';
        }

        // Show error dialog
        await AppErrorDialog.show(
          context,
          title: 'Registration Failed',
          message: errorMessage,
          actionText: 'OK',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.08,
              vertical: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: () => Navigator.pop(context),
                    color: AppColors.textDark,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideX(begin: -0.2, end: 0),

                SizedBox(height: screenHeight * 0.02),

                // Title
                Text(
                  'Create Account',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                    letterSpacing: -0.5,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 800.ms, delay: 200.ms)
                    .slideY(begin: 0.3, end: 0, duration: 600.ms),

                const SizedBox(height: 8),

                Text(
                  'Fill in your details to register',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppColors.textLight,
                    letterSpacing: 0.2,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 800.ms, delay: 400.ms)
                    .slideY(begin: 0.3, end: 0, duration: 500.ms),

                SizedBox(height: screenHeight * 0.04),

                // Form - Following web implementation order
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // 1. Email
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        hint: 'john@example.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                        delay: 300,
                      ),

                      const SizedBox(height: 16),

                      // 2. Password
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        isPassword: true,
                        isPasswordVisible: _isPasswordVisible,
                        onTogglePassword: () {
                          setState(
                              () => _isPasswordVisible = !_isPasswordVisible);
                        },
                        validator: _validatePassword,
                        delay: 350,
                      ),

                      const SizedBox(height: 16),

                      // 3. Role Dropdown
                      _buildDropdownField(
                        label: 'Role',
                        hint: 'Select your role',
                        icon: Icons.work_outline,
                        value: _selectedRole,
                        items: _roles,
                        onChanged: (value) {
                          setState(() => _selectedRole = value);
                        },
                        validator: _validateRole,
                        delay: 400,
                      ),

                      const SizedBox(height: 16),

                      // 4. Hub Dropdown
                      _buildDropdownField(
                        label: 'Select Hub',
                        hint: 'Select your hub',
                        icon: Icons.location_city_outlined,
                        value: _selectedHub,
                        items: _hubs,
                        onChanged: (value) {
                          setState(() => _selectedHub = value);
                        },
                        validator: _validateHub,
                        delay: 450,
                      ),

                      const SizedBox(height: 16),

                      // 5. Full Name
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        hint: 'John Doe',
                        icon: Icons.person_outline,
                        validator: _validateName,
                        delay: 500,
                      ),

                      const SizedBox(height: 16),

                      // 6. Phone Number
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        hint: '+249 123 456 789',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: _validatePhone,
                        delay: 550,
                      ),

                      const SizedBox(height: 16),

                      // 7. Employee ID (Optional)
                      _buildTextField(
                        controller: _employeeIdController,
                        label: 'Employee ID (Optional)',
                        hint: 'EMP001',
                        icon: Icons.badge_outlined,
                        delay: 600,
                      ),

                      const SizedBox(height: 20),

                      // Terms checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: _acceptTerms,
                            onChanged: (value) {
                              setState(() => _acceptTerms = value ?? false);
                            },
                            activeColor: AppColors.primaryOrange,
                          ),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: 'I agree to the ',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.textLight,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.primaryOrange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                          .animate()
                          .fadeIn(duration: 600.ms, delay: 650.ms)
                          .slideX(begin: -0.1, end: 0),

                      SizedBox(height: screenHeight * 0.03),

                      // Register button
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryOrange.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isLoading ? null : _handleRegister,
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                              child: Text(
                                'Create Account',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 600.ms, delay: 700.ms)
                          .slideY(begin: 0.2, end: 0),

                      SizedBox(height: screenHeight * 0.02),

                      // Login link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.textLight,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              'Sign In',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 600.ms, delay: 750.ms),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Dropdown field builder
  Widget _buildDropdownField({
    required String label,
    required String hint,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
    required int delay,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: -5,
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primaryOrange),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red),
          ),
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: AppColors.textDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: Duration(milliseconds: delay))
        .slideX(begin: 0.2, end: 0, duration: 500.ms);
  }

  // Text field builder
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onTogglePassword,
    required int delay,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: -5,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !isPasswordVisible,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.poppins(
          fontSize: 15,
          color: AppColors.textDark,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primaryOrange),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: onTogglePassword,
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: Duration(milliseconds: delay))
        .slideX(begin: 0.2, end: 0, duration: 500.ms);
  }
}
