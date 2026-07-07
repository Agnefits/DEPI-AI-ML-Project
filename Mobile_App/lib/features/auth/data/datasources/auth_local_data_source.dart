import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_model.dart';

class AuthLocalDataSource {
  final SharedPreferences prefs;

  AuthLocalDataSource({required this.prefs});

  Future<void> saveAuth(AuthModel auth) async {
    await prefs.setString('auth_id', auth.id);
    await prefs.setString('auth_email', auth.email);
    await prefs.setString('auth_name', auth.name);
    await prefs.setString('auth_token', auth.token);
    await prefs.setString('auth_refresh_token', auth.refreshToken);
  }

  Future<AuthModel?> loadAuth() async {
    final id = prefs.getString('auth_id');
    final email = prefs.getString('auth_email');
    final name = prefs.getString('auth_name');
    final token = prefs.getString('auth_token');
    if (id == null || email == null || name == null || token == null) {
      return null;
    }
    return AuthModel(
      id: id,
      email: email,
      name: name,
      token: token,
      refreshToken: prefs.getString('auth_refresh_token') ?? '',
    );
  }

  Future<void> clearAuth() async {
    final keys = prefs.getKeys().toList();
    await prefs.clear();
    print('🟢 [Logout] All stored data cleared. Removed keys (${keys.length}): $keys');
  }
}
