// lib/utils/create_test_user.dart
import '../services/auth_service.dart';

Future<void> createTestUser() async {
  final authService = AuthService();
  try {
    final response = await authService.signUp(
      email: 'francis.b.kaz@gmail.com',
      password: 'bant12345678',
    );
    print('User created successfully: ${response.user?.email}');
  } catch (e) {
    print('Error creating user: $e');
  }
}
