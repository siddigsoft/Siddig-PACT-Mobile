// lib/authentication/improved_register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_design_system.dart';
import '../widgets/app_widgets.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

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
  dynamic _profilePhoto; // File on mobile, Uint8List on web
  String? _profilePhotoUrl;
  final ImagePicker _imagePicker = ImagePicker();

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
  final _storageService = StorageService();

  Future<void> _pickProfilePhoto(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          // On web, store the bytes directly
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _profilePhoto = bytes;
          });
        } else {
          // On mobile, use File
          setState(() {
            _profilePhoto = File(pickedFile.path);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Error picking image: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  /// Upload profile photo to storage BEFORE signup (returns public URL for metadata)
  Future<String?> _uploadProfilePhotoToStorage() async {
    if (_profilePhoto == null) return null;

    try {
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'avatar-${timestamp}.jpg';

      // Read image bytes
      Uint8List imageBytes;
      if (kIsWeb) {
        imageBytes = _profilePhoto as Uint8List;
      } else {
        imageBytes = await (_profilePhoto as File).readAsBytes();
      }

      // Compress image (80% quality, max 1024x1024)
      final compressedBytes = await _compressImage(imageBytes);

      // Upload to storage using StorageService
      final storage = StorageService();
      final path = 'temp/$fileName'; // Temporary path for signup

      await storage.supabase.storage
          .from('avatars')
          .uploadBinary(
            path,
            compressedBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      // Get public URL
      final publicUrl = storage.supabase.storage
          .from('avatars')
          .getPublicUrl(path);

      debugPrint('Avatar uploaded to storage: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading avatar to storage: $e');
      // Don't fail registration if avatar upload fails
      return null;
    }
  }

  /// Compress image bytes for upload
  Future<Uint8List> _compressImage(Uint8List bytes) async {
    // For now, just return the original bytes
    // In a real implementation, you might want to use flutter_image_compress
    return bytes;
  }

  /// Move uploaded avatar from temp location to proper user location after signup
  Future<String?> _uploadProfilePhoto(String userId) async {
    if (_profilePhotoUrl == null) return null;

    try {
      final storage = StorageService();

      // If avatar was already uploaded during signup, move it to proper location
      if (_profilePhotoUrl!.contains('temp/')) {
        // Extract temp path from URL
        final uri = Uri.parse(_profilePhotoUrl!);
        final tempPath = uri.pathSegments.lastWhere(
          (segment) => segment.contains('temp/'),
        );

        // Move file from temp to user location
        final userPath = '$userId/avatar';

        // Copy file to user location
        await storage.supabase.storage.from('avatars').copy(tempPath, userPath);

        // Remove temp file
        await storage.supabase.storage.from('avatars').remove([tempPath]);

        // Get new public URL
        final newUrl = storage.supabase.storage
            .from('avatars')
            .getPublicUrl(userPath);

        // Update profile with correct avatar URL
        await storage.supabase
            .from('profiles')
            .update({'avatar_url': newUrl})
            .eq('id', userId);

        debugPrint('Avatar moved to user location: $newUrl');
        return newUrl;
      }

      return _profilePhotoUrl;
    } catch (e) {
      debugPrint('Error moving avatar to user location: $e');
      return _profilePhotoUrl; // Return original URL if move fails
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Choose Photo Source',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickProfilePhoto(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Camera'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickProfilePhoto(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
      // Step 1: Upload profile photo to storage first (if provided)
      String? avatarUrl;
      if (_profilePhoto != null) {
        avatarUrl = await _uploadProfilePhotoToStorage();
      }

      // Step 2: Register user with all metadata
      // Database triggers will automatically create profile and wallet
      final response = await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        employeeId: _employeeIdController.text.trim().isNotEmpty
            ? _employeeIdController.text.trim()
            : null,
        role: _selectedRole ?? 'dataCollector',
        hubId: _selectedHub,
        avatarUrl: avatarUrl,
      );

      if (response.user != null) {
        // Success! Triggers have created profile and wallet automatically
        AppSnackBar.show(
          context,
          message:
              'Account created successfully! Please check your email for verification.',
          type: SnackBarType.success,
        );

        // Navigate to login or success screen
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } else {
        throw Exception('Registration failed - no user returned');
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      AppSnackBar.show(
        context,
        message: 'Registration failed: ${e.toString()}',
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        AppLoadingOverlay.hide(context);
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

                // Profile Photo Section
                _buildProfilePhotoSection(),

                SizedBox(height: screenHeight * 0.03),

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
                            () => _isPasswordVisible = !_isPasswordVisible,
                          );
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
                                  color: AppColors.primaryOrange.withOpacity(
                                    0.3,
                                  ),
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
                borderSide: BorderSide(
                  color: AppColors.primaryOrange,
                  width: 2,
                ),
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
        .fadeIn(
          duration: 600.ms,
          delay: Duration(milliseconds: delay),
        )
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
                        isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
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
                borderSide: BorderSide(
                  color: AppColors.primaryOrange,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(
          duration: 600.ms,
          delay: Duration(milliseconds: delay),
        )
        .slideX(begin: 0.2, end: 0, duration: 500.ms);
  }

  Widget _buildProfilePhotoSection() {
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
      child: Column(
        children: [
          // Profile photo display or placeholder
          GestureDetector(
                onTap: () => _showPhotoOptions(),
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _profilePhoto != null
                          ? AppColors.primaryOrange
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: _profilePhoto != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: kIsWeb
                              ? Image.memory(
                                  _profilePhoto as Uint8List,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  _profilePhoto as File,
                                  fit: BoxFit.cover,
                                ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              size: 48,
                              color: AppColors.primaryOrange,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Add Profile Photo',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to upload from gallery or camera',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                ),
              )
              .animate()
              .fadeIn(
                duration: 600.ms,
                delay: const Duration(milliseconds: 200),
              )
              .slideY(begin: 0.3, end: 0, duration: 500.ms),

          // Photo options buttons (shown when photo is selected)
          if (_profilePhoto != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showPhotoOptions(),
                  icon: const Icon(Icons.edit),
                  label: const Text('Change'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _profilePhoto = null),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
          ],
        ],
      ),
    );
  }
}
