import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/user.dart';
import '../models/client_model.dart';
import '../services/project_service.dart';
import '../services/client_service.dart';
import '../services/api_service.dart';

class ProjectProvider with ChangeNotifier {
  final ProjectService _projectService = ProjectService();
  final ClientService _clientService = ClientService();

  List<Project> _projects = [];
  List<ClientModel> _clients = [];
  Project? _currentProject;
  List<User> _currentMembers = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Project> get projects => _projects;
  List<ClientModel> get clients => _clients;
  Project? get currentProject => _currentProject;
  List<User> get currentMembers => _currentMembers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadProjects({String? status, String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _projects = await _projectService.getProjects(
        status: status,
        search: search,
      );
    } catch (e) {
      _errorMessage = _parseError(e);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadProject(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentProject = await _projectService.getProject(id);
      _currentMembers = await _projectService.getMembers(id);
    } catch (e) {
      _errorMessage = _parseError(e);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Project?> createProject(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final project = await _projectService.createProject(data);
      _projects.insert(0, project);
      _isLoading = false;
      notifyListeners();
      return project;
    } catch (e) {
      _errorMessage = _parseError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateProject(String id, Map<String, dynamic> data) async {
    try {
      final updated = await _projectService.updateProject(id, data);
      final index = _projects.indexWhere((p) => p.id == id);
      if (index >= 0) _projects[index] = updated;
      if (_currentProject?.id == id) _currentProject = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProject(String id) async {
    try {
      await _projectService.deleteProject(id);
      _projects.removeWhere((p) => p.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> addMember(String projectId, String userId) async {
    try {
      await _projectService.addMember(projectId, userId);
      _currentMembers = await _projectService.getMembers(projectId);
      notifyListeners();
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
    }
  }

  Future<void> removeMember(String projectId, String userId) async {
    try {
      await _projectService.removeMember(projectId, userId);
      _currentMembers.removeWhere((m) => m.id == userId);
      notifyListeners();
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
    }
  }

  // Clients
  Future<void> loadClients({String? search}) async {
    try {
      _clients = await _clientService.getClients(search: search);
      notifyListeners();
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
    }
  }

  Future<ClientModel?> createClient(Map<String, dynamic> data) async {
    try {
      final client = await _clientService.createClient(data);
      _clients.insert(0, client);
      notifyListeners();
      return client;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateClient(String id, Map<String, dynamic> data) async {
    try {
      final updated = await _clientService.updateClient(id, data);
      final index = _clients.indexWhere((c) => c.id == id);
      if (index >= 0) _clients[index] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteClient(String id) async {
    try {
      await _clientService.deleteClient(id);
      _clients.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _parseError(dynamic error) {
    if (error is ApiException) return error.message;
    return 'Ocorreu um erro. Tente novamente.';
  }
}
