import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/socket_service.dart';

class TaskProvider extends ChangeNotifier {
  final TaskService _taskService = TaskService();
  final SocketService _socketService = SocketService();

  List<Task> _tasks = [];
  List<Task> _myTasks = [];
  Task? _selectedTask;
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentProjectId;

  List<Task> get tasks => _tasks;
  List<Task> get myTasks => _myTasks;
  Task? get selectedTask => _selectedTask;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Kanban board columns
  List<Task> get todoTasks =>
      _tasks.where((t) => t.status == TaskStatus.todo).toList();
  List<Task> get inProgressTasks =>
      _tasks.where((t) => t.status == TaskStatus.inProgress).toList();
  List<Task> get reviewTasks =>
      _tasks.where((t) => t.status == TaskStatus.review).toList();
  List<Task> get doneTasks =>
      _tasks.where((t) => t.status == TaskStatus.done).toList();

  TaskProvider() {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    _socketService.on('task:created', (data) {
      if (data is Map<String, dynamic>) {
        final task = Task.fromJson(data);
        if (task.projectId == _currentProjectId) {
          _tasks.add(task);
          notifyListeners();
        }
      }
    });

    _socketService.on('task:updated', (data) {
      if (data is Map<String, dynamic>) {
        final updated = Task.fromJson(data);
        _updateTaskInList(updated);
      }
    });

    _socketService.on('task:statusChanged', (data) {
      if (data is Map<String, dynamic>) {
        final updated = Task.fromJson(data);
        _updateTaskInList(updated);
      }
    });

    _socketService.on('task:deleted', (data) {
      if (data is Map<String, dynamic>) {
        final taskId = data['_id'] ?? data['id'];
        if (taskId != null) {
          _tasks.removeWhere((t) => t.id == taskId);
          if (_selectedTask?.id == taskId) {
            _selectedTask = null;
          }
          notifyListeners();
        }
      }
    });
  }

  void _updateTaskInList(Task updated) {
    final index = _tasks.indexWhere((t) => t.id == updated.id);
    if (index != -1) {
      _tasks[index] = updated;
    }
    if (_selectedTask?.id == updated.id) {
      _selectedTask = updated;
    }
    // Also update in myTasks
    final myIndex = _myTasks.indexWhere((t) => t.id == updated.id);
    if (myIndex != -1) {
      _myTasks[myIndex] = updated;
    }
    notifyListeners();
  }

  Future<void> loadTasks(String projectId) async {
    _isLoading = true;
    _errorMessage = null;
    _currentProjectId = projectId;
    notifyListeners();

    try {
      _tasks = await _taskService.getTasks(projectId);
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTask(String projectId, String taskId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedTask = await _taskService.getTask(projectId, taskId);
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Task?> createTask(String projectId, Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final task = await _taskService.createTask(projectId, data);
      _tasks.add(task);
      _isLoading = false;
      notifyListeners();
      return task;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateTask(
      String projectId, String taskId, Map<String, dynamic> data) async {
    try {
      final updated = await _taskService.updateTask(projectId, taskId, data);
      _updateTaskInList(updated);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTaskStatus(
      String projectId, String taskId, TaskStatus newStatus) async {
    // Optimistic update
    final index = _tasks.indexWhere((t) => t.id == taskId);
    Task? oldTask;
    if (index != -1) {
      oldTask = _tasks[index];
      _tasks[index] = oldTask.copyWith(status: newStatus);
      notifyListeners();
    }

    try {
      final updated =
          await _taskService.updateTaskStatus(projectId, taskId, newStatus.value);
      _updateTaskInList(updated);
      return true;
    } catch (e) {
      // Rollback on error
      if (oldTask != null && index != -1) {
        _tasks[index] = oldTask;
        notifyListeners();
      }
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTask(String projectId, String taskId) async {
    try {
      await _taskService.deleteTask(projectId, taskId);
      _tasks.removeWhere((t) => t.id == taskId);
      if (_selectedTask?.id == taskId) {
        _selectedTask = null;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadMyTasks({String? status}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _myTasks = await _taskService.getMyTasks(status: status);
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearTasks() {
    _tasks = [];
    _currentProjectId = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
