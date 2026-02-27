import '../config/api_config.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _api.post(
      ApiConfig.login,
      body: {'email': email, 'password': password},
    );
    final accessToken = data['access_token'] ?? data['token'];
    final refreshToken = data['refresh_token'] ?? '';
    await _api.saveTokens(accessToken, refreshToken);
    return data;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final data = await _api.post(
      ApiConfig.register,
      body: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
    if (data['access_token'] != null || data['token'] != null) {
      final accessToken = data['access_token'] ?? data['token'];
      final refreshToken = data['refresh_token'] ?? '';
      await _api.saveTokens(accessToken, refreshToken);
    }
    return data;
  }

  Future<User> me() async {
    final data = await _api.get(ApiConfig.me);
    return User.fromJson(data['user'] ?? data);
  }

  Future<User> updateProfile(Map<String, dynamic> updates) async {
    final data = await _api.put(ApiConfig.updateProfile, body: updates);
    return User.fromJson(data['user'] ?? data);
  }

  Future<void> logout() async {
    try {
      await _api.post(ApiConfig.logout);
    } catch (_) {}
    await _api.clearTokens();
  }

  Future<void> refresh() async {
    await _api.loadTokens();
  }
}
