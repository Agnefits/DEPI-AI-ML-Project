class RegisterRequestModel {
  final String username;
  final String fullName;
  final String email;
  final String password;
  final String phone;
  final String role;

  RegisterRequestModel({
    required this.username,
    required this.fullName,
    required this.email,
    required this.password,
    this.phone = '',
    this.role = 'Doctor',
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'fullName': fullName,
      'email': email,
      'password': password,
      'phone': phone,
      'role': role,
    };
  }
}
