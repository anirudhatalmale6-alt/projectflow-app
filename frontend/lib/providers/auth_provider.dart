import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();

  AuthState _state = AuthState.initial;
  User? _user;
  String? _errorMessage;

  AuthState get state => _state;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;

  // Role checks
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isManager => _user?.isManager ?? false;
  bool get isEditor => _user?.isEditor ?? false;
  bool get isFreelancer => _user?.isFreelancer ?? false;
  bool get isClient => _user?.isClient ?? false;
  bool get canManageProjects => _user?.canManageProjects ?? false;
  bool get canManageUsers => _user?.canManageUsers ?? false;
  bool get canAssignTasks => _user?.canAssignTasks ?? false;
  bool get canApproveDeliveries => _user?.canApproveDeliveries ?? false;

  Future<void> initialize() async {
    _state = AuthState.loading;
    notifyListeners();

    try {
      await _apiService.loadTokens();
      if (_apiService.hasTokens) {
        _user = await _authService.me();
        _state = AuthState.authenticated;
      } else {
        _state = AuthState.unauthenticated;
      }
    } catch (e) {
      _state = AuthState.unauthenticated;
      await _apiService.clearTokens();
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _authService.login(email, password);
      _user = User.fromJson(data['user'] ?? {});
      if (_user!.id.isEmpty) {
        _user = await _authService.me();
      }
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _authService.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      _user = User.fromJson(data['user'] ?? {});
      if (_user!.id.isEmpty) {
        _user = await _authService.me();
      }
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _socketService.disconnect();
    await _authService.logout();
    _user = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    try {
      _user = await _authService.updateProfile(updates);
      notifyListeners();
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _errorMessage = null;
    if (_state == AuthState.error) {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  String _parseError(dynamic error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Ocorreu um erro inesperado. Tente novamente.';
  }
}
