import '../config/api_config.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _api.post(
      ApiConfig.login,
      body: {
        'email': email,
        'password': password,
      },
      auth: false,
    );

    final token = response['token'] ?? response['accessToken'];
    final userData = response['user'] ?? response['data'];

    if (token != null) {
      await _api.setToken(token);
    }

    return {
      'token': token,
      'user': userData != null ? User.fromJson(userData) : null,
    };
  }

  Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    final response = await _api.post(
      ApiConfig.register,
      body: {
        'name': name,
        'email': email,
        'password': password,
      },
      auth: false,
    );

    final token = response['token'] ?? response['accessToken'];
    final userData = response['user'] ?? response['data'];

    if (token != null) {
      await _api.setToken(token);
    }

    return {
      'token': token,
      'user': userData != null ? User.fromJson(userData) : null,
    };
  }

  Future<User> getProfile() async {
    final response = await _api.get(ApiConfig.profile);
    final userData = response['user'] ?? response['data'] ?? response;
    return User.fromJson(userData);
  }

  Future<User> updateProfile(Map<String, dynamic> data) async {
    final response = await _api.put(ApiConfig.updateProfile, body: data);
    final userData = response['user'] ?? response['data'] ?? response;
    return User.fromJson(userData);
  }

  Future<void> logout() async {
    await _api.setToken(null);
  }

  Future<bool> isLoggedIn() async {
    final token = await _api.token;
    return token != null && token.isNotEmpty;
  }
}
