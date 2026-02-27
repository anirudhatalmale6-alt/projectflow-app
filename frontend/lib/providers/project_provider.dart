import 'package:flutter/foundation.dart';
import '../models/project.dart';
import '../services/project_service.dart';
import '../services/socket_service.dart';

class ProjectProvider extends ChangeNotifier {
  final ProjectService _projectService = ProjectService();
  final SocketService _socketService = SocketService();

  List<Project> _projects = [];
  Project? _selectedProject;
  bool _isLoading = false;
  String? _errorMessage;

  List<Project> get projects => _projects;
  Project? get selectedProject => _selectedProject;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ProjectProvider() {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    _socketService.on('project:updated', (data) {
      if (data is Map<String, dynamic>) {
        final updated = Project.fromJson(data);
        final index = _projects.indexWhere((p) => p.id == updated.id);
        if (index != -1) {
          _projects[index] = updated;
          if (_selectedProject?.id == updated.id) {
            _selectedProject = updated;
          }
          notifyListeners();
        }
      }
    });
  }

  Future<void> loadProjects() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _projects = await _projectService.getProjects();
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadProject(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedProject = await _projectService.getProject(id);
      _socketService.joinProject(id);
    } catch (e) {
      _errorMessage = e.toString();
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
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateProject(String id, Map<String, dynamic> data) async {
    try {
      final updated = await _projectService.updateProject(id, data);
      final index = _projects.indexWhere((p) => p.id == id);
      if (index != -1) {
        _projects[index] = updated;
      }
      if (_selectedProject?.id == id) {
        _selectedProject = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProject(String id) async {
    try {
      await _projectService.deleteProject(id);
      _projects.removeWhere((p) => p.id == id);
      if (_selectedProject?.id == id) {
        _selectedProject = null;
        _socketService.leaveProject(id);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> addMember(String projectId, String email, {String role = 'member'}) async {
    try {
      await _projectService.addMember(projectId, email, role: role);
      await loadProject(projectId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeMember(String projectId, String userId) async {
    try {
      await _projectService.removeMember(projectId, userId);
      await loadProject(projectId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void leaveProject(String id) {
    _socketService.leaveProject(id);
    _selectedProject = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_selectedProject != null) {
      _socketService.leaveProject(_selectedProject!.id);
    }
    super.dispose();
  }
}
