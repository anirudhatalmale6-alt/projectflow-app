import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? errors;

  ApiException({
    required this.statusCode,
    required this.message,
    this.errors,
  });

  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;

  Future<String?> get token async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    return _token;
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('jwt_token', token);
    } else {
      await prefs.remove('jwt_token');
    }
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final t = await token;
      if (t != null) {
        headers['Authorization'] = 'Bearer $t';
      }
    }
    return headers;
  }

  Future<dynamic> get(String url, {bool auth = true}) async {
    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: await _headers(auth: auth),
          )
          .timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(statusCode: 0, message: 'No internet connection');
    }
  }

  Future<dynamic> post(String url, {dynamic body, bool auth = true}) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: await _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(statusCode: 0, message: 'No internet connection');
    }
  }

  Future<dynamic> put(String url, {dynamic body, bool auth = true}) async {
    try {
      final response = await http
          .put(
            Uri.parse(url),
            headers: await _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(statusCode: 0, message: 'No internet connection');
    }
  }

  Future<dynamic> patch(String url, {dynamic body, bool auth = true}) async {
    try {
      final response = await http
          .patch(
            Uri.parse(url),
            headers: await _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(statusCode: 0, message: 'No internet connection');
    }
  }

  Future<dynamic> delete(String url, {bool auth = true}) async {
    try {
      final response = await http
          .delete(
            Uri.parse(url),
            headers: await _headers(auth: auth),
          )
          .timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(statusCode: 0, message: 'No internet connection');
    }
  }

  dynamic _handleResponse(http.Response response) {
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    String message = 'An error occurred';
    Map<String, dynamic>? errors;

    if (body is Map<String, dynamic>) {
      message = body['message'] ?? body['error'] ?? message;
      errors = body['errors'] is Map<String, dynamic> ? body['errors'] : null;
    }

    if (response.statusCode == 401) {
      // Token expired or invalid - clear token
      setToken(null);
      message = 'Session expired. Please login again.';
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: message,
      errors: errors,
    );
  }
}
