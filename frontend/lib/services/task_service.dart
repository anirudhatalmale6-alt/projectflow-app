import '../config/api_config.dart';
import '../models/task.dart';
import 'api_service.dart';

class TaskService {
  final ApiService _api = ApiService();

  Future<List<Task>> getTasks({
    String? projectId,
    String? status,
    String? assigneeId,
    String? search,
  }) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (assigneeId != null) params['assignee_id'] = assigneeId;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final path = projectId != null
        ? ApiConfig.tasksByProject(projectId)
        : ApiConfig.tasks;

    final data = await _api.get(path, queryParams: params);
    final list = data['tasks'] ?? data['data'] ?? data;
    return (list as List).map((json) => Task.fromJson(json)).toList();
  }

  Future<Task> getTask(String id) async {
    final data = await _api.get(ApiConfig.taskById(id));
    return Task.fromJson(data['task'] ?? data);
  }

  Future<Task> createTask(Map<String, dynamic> taskData) async {
    final data = await _api.post(ApiConfig.tasks, body: taskData);
    return Task.fromJson(data['task'] ?? data);
  }

  Future<Task> updateTask(String id, Map<String, dynamic> taskData) async {
    final data = await _api.put(ApiConfig.taskById(id), body: taskData);
    return Task.fromJson(data['task'] ?? data);
  }

  Future<void> deleteTask(String id) async {
    await _api.delete(ApiConfig.taskById(id));
  }

  Future<void> updateStatus(String id, String status) async {
    await _api.patch(ApiConfig.taskStatus(id), body: {'status': status});
  }

  Future<void> updatePosition(String id, int position, {String? status}) async {
    await _api.patch(
      ApiConfig.taskPosition(id),
      body: {'position': position, if (status != null) 'status': status},
    );
  }

  Future<void> updateHours(String id, double actualHours) async {
    await _api.patch(
      ApiConfig.taskHours(id),
      body: {'actual_hours': actualHours},
    );
  }
}
