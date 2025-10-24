class UserProfile {
  String userId;
  String fullName;
  String email;
  String role; // 'admin', 'manager', 'worker'
  String department;
  DateTime lastLogin;
  Map<String, dynamic>? preferences;
  List<String> permissions;

  UserProfile({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.department,
    required this.lastLogin,
    this.preferences,
    required this.permissions,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'role': role,
      'department': department,
      'lastLogin': lastLogin.toIso8601String(),
      'preferences': preferences,
      'permissions': permissions,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'],
      fullName: json['fullName'],
      email: json['email'],
      role: json['role'],
      department: json['department'],
      lastLogin: DateTime.parse(json['lastLogin']),
      preferences: json['preferences'],
      permissions: List<String>.from(json['permissions']),
    );
  }
}