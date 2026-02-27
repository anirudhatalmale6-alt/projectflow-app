import '../config/api_config.dart';
import '../models/task.dart';
import 'api_service.dart';

class TaskService {
  final ApiService _api = ApiService();

  Future<List<Task>> getTasks(String projectId, {String? status, String? assignee}) async {
    String url = ApiConfig.tasks(projectId);
    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;
    if (assignee != null) queryParams['assignee'] = assignee;
    if (queryParams.isNotEmpty) {
      url += '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    }
    final response = await _api.get(url);
    final List<dynamic> data = response['tasks'] ?? response['data'] ?? response;
    return data.map((json) => Task.fromJson(json)).toList();
  }

  Future<Task> getTask(String projectId, String taskId) async {
    final response = await _api.get(ApiConfig.task(projectId, taskId));
    final data = response['task'] ?? response['data'] ?? response;
    return Task.fromJson(data);
  }

  Future<Task> createTask(String projectId, Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.tasks(projectId), body: data);
    final taskData = response['task'] ?? response['data'] ?? response;
    return Task.fromJson(taskData);
  }

  Future<Task> updateTask(
      String projectId, String taskId, Map<String, dynamic> data) async {
    final response =
        await _api.put(ApiConfig.task(projectId, taskId), body: data);
    final taskData = response['task'] ?? response['data'] ?? response;
    return Task.fromJson(taskData);
  }

  Future<Task> updateTaskStatus(
      String projectId, String taskId, String status) async {
    final response = await _api.patch(
      ApiConfig.taskStatus(projectId, taskId),
      body: {'status': status},
    );
    final taskData = response['task'] ?? response['data'] ?? response;
    return Task.fromJson(taskData);
  }

  Future<Task> assignTask(
      String projectId, String taskId, String assigneeId) async {
    final response = await _api.patch(
      ApiConfig.taskAssign(projectId, taskId),
      body: {'assignee': assigneeId},
    );
    final taskData = response['task'] ?? response['data'] ?? response;
    return Task.fromJson(taskData);
  }

  Future<void> deleteTask(String projectId, String taskId) async {
    await _api.delete(ApiConfig.task(projectId, taskId));
  }

  Future<List<Task>> getMyTasks({String? status}) async {
    String url = ApiConfig.myTasks;
    if (status != null) {
      url += '?status=$status';
    }
    final response = await _api.get(url);
    final List<dynamic> data = response['tasks'] ?? response['data'] ?? response;
    return data.map((json) => Task.fromJson(json)).toList();
  }
}
