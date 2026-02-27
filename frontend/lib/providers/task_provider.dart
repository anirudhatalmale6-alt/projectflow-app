import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/api_service.dart';

class TaskProvider with ChangeNotifier {
  final TaskService _taskService = TaskService();

  List<Task> _tasks = [];
  Task? _currentTask;
  bool _isLoading = false;
  String? _errorMessage;

  List<Task> get tasks => _tasks;
  Task? get currentTask => _currentTask;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Kanban columns
  List<Task> get todoTasks => _tasks.where((t) => t.status == 'todo').toList()
    ..sort((a, b) => a.position.compareTo(b.position));
  List<Task> get inProgressTasks =>
      _tasks.where((t) => t.status == 'in_progress').toList()
        ..sort((a, b) => a.position.compareTo(b.position));
  List<Task> get reviewTasks =>
      _tasks.where((t) => t.status == 'review').toList()
        ..sort((a, b) => a.position.compareTo(b.position));
  List<Task> get doneTasks => _tasks.where((t) => t.status == 'done').toList()
    ..sort((a, b) => a.position.compareTo(b.position));

  Future<void> loadTasks({String? projectId, String? assigneeId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _tasks = await _taskService.getTasks(
        projectId: projectId,
        assigneeId: assigneeId,
      );
    } catch (e) {
      _errorMessage = _parseError(e);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTask(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentTask = await _taskService.getTask(id);
    } catch (e) {
      _errorMessage = _parseError(e);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Task?> createTask(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final task = await _taskService.createTask(data);
      _tasks.add(task);
      _isLoading = false;
      notifyListeners();
      return task;
    } catch (e) {
      _errorMessage = _parseError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateTask(String id, Map<String, dynamic> data) async {
    try {
      final updated = await _taskService.updateTask(id, data);
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index >= 0) _tasks[index] = updated;
      if (_currentTask?.id == id) _currentTask = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTask(String id) async {
    try {
      await _taskService.deleteTask(id);
      _tasks.removeWhere((t) => t.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> moveTask(String taskId, String newStatus, int newPosition) async {
    // Optimistic update
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return false;

    final oldTask = _tasks[index];
    _tasks[index] = oldTask.copyWith(status: newStatus, position: newPosition);
    notifyListeners();

    try {
      await _taskService.updatePosition(taskId, newPosition, status: newStatus);
      return true;
    } catch (e) {
      // Rollback
      _tasks[index] = oldTask;
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTaskStatus(String taskId, String status) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return false;

    final oldTask = _tasks[index];
    _tasks[index] = oldTask.copyWith(status: status);
    notifyListeners();

    try {
      await _taskService.updateStatus(taskId, status);
      return true;
    } catch (e) {
      _tasks[index] = oldTask;
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateHours(String taskId, double hours) async {
    try {
      await _taskService.updateHours(taskId, hours);
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index >= 0) {
        _tasks[index] = _tasks[index].copyWith(actualHours: hours);
      }
      if (_currentTask?.id == taskId) {
        _currentTask = _currentTask!.copyWith(actualHours: hours);
      }
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
