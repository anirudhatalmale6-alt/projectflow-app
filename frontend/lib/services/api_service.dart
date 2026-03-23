import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Callback for upload progress: receives bytes sent and total bytes.
typedef UploadProgressCallback = void Function(int bytesSent, int totalBytes);

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
  Completer<bool>? _refreshCompleter;
  DateTime? _tokenExpiresAt;

  String get baseUrl => ApiConfig.baseUrl;

  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshTokenValue = prefs.getString('refresh_token');
    if (_accessToken != null) {
      _tokenExpiresAt = _parseJwtExpiry(_accessToken!);
    }
  }

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshTokenValue = refreshToken;
    _tokenExpiresAt = _parseJwtExpiry(accessToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  /// Parse the expiry time from a JWT token without verifying signature.
  DateTime? _parseJwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      // Decode the payload (base64url)
      String payload = parts[1];
      // Pad to multiple of 4
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final Map<String, dynamic> payloadMap = jsonDecode(decoded);
      if (payloadMap.containsKey('exp')) {
        return DateTime.fromMillisecondsSinceEpoch(
          (payloadMap['exp'] as num).toInt() * 1000,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Returns true if the access token will expire within the given duration.
  bool _isTokenExpiringSoon({Duration threshold = const Duration(minutes: 5)}) {
    if (_tokenExpiresAt == null) return false;
    return DateTime.now().isAfter(_tokenExpiresAt!.subtract(threshold));
  }

  /// Proactively refresh the token if it is about to expire.
  /// Uses a Completer to avoid concurrent refresh requests.
  Future<void> _ensureValidToken() async {
    if (_accessToken == null) return;
    if (!_isTokenExpiringSoon()) return;

    // If already refreshing, wait for it to complete
    if (_isRefreshing && _refreshCompleter != null) {
      await _refreshCompleter!.future;
      return;
    }

    await _refreshToken();
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

    final message = body is Map
        ? (body['message'] ?? body['error'] ?? 'Erro HTTP ${response.statusCode}')
        : 'Erro HTTP ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}';
    throw ApiException(response.statusCode, message, data: body);
  }

  Future<bool> _refreshToken() async {
    if (_refreshTokenValue == null) return false;

    // If already refreshing, wait for the existing refresh to complete
    if (_isRefreshing && _refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

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
        _refreshCompleter!.complete(true);
        _refreshCompleter = null;
        return true;
      }
    } catch (_) {}

    _isRefreshing = false;
    _refreshCompleter!.complete(false);
    _refreshCompleter = null;
    await clearTokens();
    return false;
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    await _ensureValidToken();
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
    await _ensureValidToken();
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
    await _ensureValidToken();
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
    await _ensureValidToken();
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
    await _ensureValidToken();
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

  Future<dynamic> multipartPostBytes(
    String path, {
    required Map<String, String> fields,
    required List<int> fileBytes,
    required String fileName,
    String fileField = 'file',
    UploadProgressCallback? onProgress,
  }) async {
    await _ensureValidToken();
    final uri = _buildUri(path);
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers);
    request.headers.remove('Content-Type');
    request.fields.addAll(fields);

    request.files.add(http.MultipartFile.fromBytes(
      fileField,
      fileBytes,
      filename: fileName,
    ));

    if (onProgress != null) {
      // Calculate total size for progress tracking
      final totalBytes = request.contentLength;

      // Finalize the request to get the byte stream
      final byteStream = request.finalize();

      // Create a StreamedRequest to track bytes sent
      final streamedRequest = http.StreamedRequest('POST', uri);
      streamedRequest.headers.addAll(request.headers);
      streamedRequest.contentLength = totalBytes;

      int bytesSent = 0;
      byteStream.listen(
        (chunk) {
          bytesSent += chunk.length;
          onProgress(bytesSent, totalBytes);
          streamedRequest.sink.add(chunk);
        },
        onDone: () => streamedRequest.sink.close(),
        onError: (e) => streamedRequest.sink.addError(e),
      );

      final client = http.Client();
      try {
        final streamedResponse = await client.send(streamedRequest);
        final response = await http.Response.fromStream(streamedResponse);
        return _handleResponse(response);
      } finally {
        client.close();
      }
    } else {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    }
  }

  Future<dynamic> uploadFile(
    String path,
    List<int> bytes,
    String fileName, {
    String fieldName = 'file',
    Map<String, String>? fields,
    UploadProgressCallback? onProgress,
  }) async {
    return multipartPostBytes(
      path,
      fields: fields ?? {},
      fileBytes: bytes,
      fileName: fileName,
      fileField: fieldName,
      onProgress: onProgress,
    );
  }
}
