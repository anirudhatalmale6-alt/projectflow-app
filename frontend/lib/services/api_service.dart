import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic data;

  ApiException(this.statusCode, this.message, {this.data});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _accessToken;
  String? _refreshTokenValue;
  bool _isRefreshing = false;

  String get baseUrl => ApiConfig.baseUrl;

  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshTokenValue = prefs.getString('refresh_token');
  }

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshTokenValue = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshTokenValue = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  bool get hasTokens => _accessToken != null && _accessToken!.isNotEmpty;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Uri _buildUri(String path, {Map<String, String>? queryParams}) {
    final uri = Uri.parse('$baseUrl$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  Future<dynamic> _handleResponse(http.Response response) async {
    final body =
        response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (response.statusCode == 401 && !_isRefreshing) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        return null; // Caller should retry
      }
    }

    final message = body is Map ? (body['message'] ?? 'Erro desconhecido') : 'Erro desconhecido';
    throw ApiException(response.statusCode, message, data: body);
  }

  Future<bool> _refreshToken() async {
    if (_refreshTokenValue == null) return false;
    _isRefreshing = true;

    try {
      final response = await http.post(
        _buildUri(ApiConfig.refreshToken),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshTokenValue}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveTokens(
          data['access_token'] ?? data['token'],
          data['refresh_token'] ?? _refreshTokenValue!,
        );
        _isRefreshing = false;
        return true;
      }
    } catch (_) {}

    _isRefreshing = false;
    await clearTokens();
    return false;
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    final response = await http.get(
      _buildUri(path, queryParams: queryParams),
      headers: _headers,
    );

    final result = await _handleResponse(response);
    if (result == null && response.statusCode == 401) {
      // Retry with new token
      final retryResponse = await http.get(
        _buildUri(path, queryParams: queryParams),
        headers: _headers,
      );
      return _handleResponse(retryResponse);
    }
    return result;
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final response = await http.post(
      _buildUri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );

    final result = await _handleResponse(response);
    if (result == null && response.statusCode == 401) {
      final retryResponse = await http.post(
        _buildUri(path),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(retryResponse);
    }
    return result;
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final response = await http.put(
      _buildUri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );

    final result = await _handleResponse(response);
    if (result == null && response.statusCode == 401) {
      final retryResponse = await http.put(
        _buildUri(path),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(retryResponse);
    }
    return result;
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    final response = await http.patch(
      _buildUri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );

    final result = await _handleResponse(response);
    if (result == null && response.statusCode == 401) {
      final retryResponse = await http.patch(
        _buildUri(path),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(retryResponse);
    }
    return result;
  }

  Future<dynamic> delete(String path) async {
    final response = await http.delete(
      _buildUri(path),
      headers: _headers,
    );

    final result = await _handleResponse(response);
    if (result == null && response.statusCode == 401) {
      final retryResponse = await http.delete(
        _buildUri(path),
        headers: _headers,
      );
      return _handleResponse(retryResponse);
    }
    return result;
  }

  Future<dynamic> multipartPost(
    String path, {
    required Map<String, String> fields,
    String? filePath,
    String? fileField,
  }) async {
    final uri = _buildUri(path);
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers);
    request.headers.remove('Content-Type');
    request.fields.addAll(fields);

    if (filePath != null && fileField != null) {
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }
}
